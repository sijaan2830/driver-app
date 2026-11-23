import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'proof_screen.dart';

/// Scan QR bag tags (pickup: attach tags to the order · delivery: check the right bags).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.jobId});
  final String jobId;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128]);
  final List<String> _tags = [];
  int _bags = 1;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    final j = context.read<AppState>().byId(widget.jobId);
    if (j != null && j.bags > 0) _bags = j.bags;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw, Job job) {
    final t = scanCode(raw);
    if (t.isEmpty || _tags.contains(t)) return;
    HapticFeedback.mediumImpact();
    if (!job.isPickup && job.bagTags.isNotEmpty && !job.bagTags.contains(t)) {
      HapticFeedback.vibrate();
      toast(context, '$t is not one of this order\'s bags.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _tags.add(t);
      if (_tags.length > _bags) _bags = _tags.length;
    });
  }

  Future<void> _type(Job job) async {
    final c = TextEditingController(text: 'BAG-');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Type bag tag', style: DC.h(20)),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Tag, e.g. BAG-1042')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), style: FilledButton.styleFrom(backgroundColor: DC.forest), child: const Text('Add')),
        ],
      ),
    );
    if (v != null) _add(v, job);
  }

  @override
  Widget build(BuildContext context) {
    final job = context.watch<AppState>().byId(widget.jobId);
    if (job == null) return const Scaffold();
    final expected = job.bagTags;
    return Scaffold(
      appBar: AppBar(title: Text(job.isPickup ? 'Collect bags' : 'Check bags')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 280,
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(
                controller: _ctrl,
                onDetect: (cap) {
                  for (final b in cap.barcodes) {
                    final v = b.rawValue;
                    if (v != null) _add(v, job);
                  }
                },
                errorBuilder: (_, e) => Container(
                  color: DC.deep,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Text('Camera not available.\nType the tag instead.', textAlign: TextAlign.center, style: DC.t(15, color: Colors.white)),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(border: Border.all(color: DC.gold, width: 3), borderRadius: BorderRadius.circular(22)),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                  onPressed: () {
                    _ctrl.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Text('Point at the QR tag on each bag', textAlign: TextAlign.center, style: DC.t(13.5, color: Colors.white, w: FontWeight.w700)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _type(job),
          icon: const Icon(Icons.keyboard_alt_outlined, color: DC.forest),
          label: Text('Type a tag instead', style: DC.t(14, w: FontWeight.w700)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
        SectionTitle('Scanned (${_tags.length}${expected.isNotEmpty ? '/${expected.length}' : ''})'),
        if (_tags.isEmpty)
          Text(job.isPickup ? 'No tags yet. You can also continue with a bag count only.' : 'Scan the bags you are handing over.', style: DC.t(13.5, color: DC.mut, w: FontWeight.w500))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _tags)
              Chip(
                label: Text(t, style: DC.t(13, color: DC.emerald2, w: FontWeight.w800)),
                backgroundColor: DC.mint,
                side: const BorderSide(color: Color(0xFFA7F3D0)),
                avatar: const Icon(Icons.check_circle_rounded, color: DC.emerald, size: 18),
                onDeleted: () => setState(() => _tags.remove(t)),
              ),
          ]),
        const SectionTitle('Number of bags'),
        AppCard(
          child: Row(children: [
            const IconTile(Icons.shopping_bag_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text('$_bags bag${_bags == 1 ? '' : 's'}', style: DC.h(20))),
            IconButton.filledTonal(onPressed: _bags > 1 ? () => setState(() => _bags--) : null, icon: const Icon(Icons.remove_rounded)),
            const SizedBox(width: 6),
            IconButton.filled(style: IconButton.styleFrom(backgroundColor: DC.forest), onPressed: () => setState(() => _bags++), icon: const Icon(Icons.add_rounded)),
          ]),
        ),
      ]),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: DC.line))),
        child: Btn('Continue', icon: Icons.arrow_forward_rounded, onTap: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProofScreen(jobId: job.id, tags: List.of(_tags), bags: _bags)));
        }),
      ),
    );
  }
}
