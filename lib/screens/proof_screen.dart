import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../data/job_repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'done_screen.dart';

/// Proof of collection / delivery: doorstep photo, optional signature, payment for deliveries.
class ProofScreen extends StatefulWidget {
  const ProofScreen({super.key, required this.jobId, required this.tags, required this.bags});
  final String jobId;
  final List<String> tags;
  final int bags;
  @override
  State<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<ProofScreen> {
  final _sig = SignatureController(penStrokeWidth: 3, penColor: DC.ink, exportBackgroundColor: Colors.white);
  final _note = TextEditingController();
  Uint8List? _photo;
  String? _payment;
  bool _busy = false;

  @override
  void dispose() {
    _sig.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 78);
    if (x != null) {
      final b = await x.readAsBytes();
      setState(() => _photo = b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final job = s.byId(widget.jobId);
    if (job == null) return const Scaffold();
    final needsPay = !job.isPickup && job.amountDue > 0;
    final canFinish = _photo != null && (!needsPay || _payment != null);

    return Scaffold(
      appBar: AppBar(title: Text(job.isPickup ? 'Confirm collection' : 'Confirm delivery')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 150), children: [
        AppCard(
          color: DC.mint,
          border: const Color(0xFFA7F3D0),
          child: Row(children: [
            const IconTile(Icons.shopping_bag_rounded, bg: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.bags} bag${widget.bags == 1 ? '' : 's'} · ${job.customerName}', style: DC.t(15.5, w: FontWeight.w800)),
                Text(widget.tags.isEmpty ? 'No tags scanned' : widget.tags.join(', '), style: DC.t(12.5, color: DC.emerald2)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Photo at the door'),
        AppCard(
          padding: EdgeInsets.zero,
          onTap: _takePhoto,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: _photo == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const IconTile(Icons.photo_camera_rounded, size: 58),
                      const SizedBox(height: 10),
                      Text('Tap to take a photo', style: DC.t(15, w: FontWeight.w800)),
                      Text(job.isPickup ? 'Show the bags at the door' : 'Show where you left the items', style: DC.t(12.5, color: DC.mut)),
                    ])
                  : Stack(fit: StackFit.expand, children: [
                      Image.memory(_photo!, fit: BoxFit.cover),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retake'),
                        ),
                      ),
                    ]),
            ),
          ),
        ),
        SectionTitle('Signature', trailing: Text('optional', style: DC.t(12.5, color: DC.mut))),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Signature(controller: _sig, height: 160, backgroundColor: const Color(0xFFF8FAFC))),
            Row(children: [
              Padding(padding: const EdgeInsets.only(left: 8), child: Text('Ask ${job.firstName} to sign above', style: DC.t(12.5, color: DC.mut))),
              const Spacer(),
              TextButton(onPressed: _sig.clear, child: const Text('Clear')),
            ]),
          ]),
        ),
        if (needsPay) ...[
          SectionTitle('Payment · £${job.amountDue.toStringAsFixed(2)}'),
          Row(children: [
            for (final (v, l, i) in const [('card', 'Card', Icons.contactless_rounded), ('cash', 'Cash', Icons.payments_rounded), ('prepaid', 'Already paid', Icons.verified_rounded)])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: _payment == v ? DC.mint : Colors.white,
                    border: _payment == v ? DC.emerald : null,
                    onTap: () => setState(() => _payment = v),
                    child: Column(children: [
                      Icon(i, color: _payment == v ? DC.emerald : DC.forest),
                      const SizedBox(height: 6),
                      Text(l, style: DC.t(13, w: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note for the office (optional)')),
      ]),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: DC.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!canFinish)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_photo == null ? 'Take a photo to finish' : 'Choose how the customer paid', style: DC.t(12.5, color: DC.mut)),
            ),
          Btn(job.isPickup ? 'Confirm collection' : 'Confirm delivery', icon: Icons.check_rounded, busy: _busy, onTap: !canFinish
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final sig = _sig.isNotEmpty ? await _sig.toPngBytes() : null;
                    await s.complete(job, Proof(bagTags: widget.tags, bags: widget.bags, photo: _photo, signature: sig, payment: _payment, note: _note.text.trim()));
                    if (!context.mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DoneScreen(jobId: job.id)));
                  } catch (e) {
                    if (context.mounted) toast(context, 'Could not save. Check your signal and try again.');
                    setState(() => _busy = false);
                  }
                }),
        ]),
      ),
    );
  }
}
