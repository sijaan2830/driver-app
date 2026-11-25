import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/geo.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/launch.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';
import 'scan_screen.dart';
import 'trip_screen.dart';

class JobScreen extends StatelessWidget {
  const JobScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final job = s.byId(jobId);
    if (job == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final d = s.distanceTo(job);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: job.hasGeo ? 250 : 110,
          backgroundColor: DC.forest,
          foregroundColor: Colors.white,
          title: Text('#${job.orderId}', style: DC.h(18, color: Colors.white)),
          flexibleSpace: FlexibleSpaceBar(
            background: job.hasGeo
                ? RouteMap(me: s.me, heading: s.heading, stops: [job], focus: job, line: s.me != null, interactive: false)
                : Container(
                    decoration: const BoxDecoration(gradient: DC.heroGradient),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      job.postcode.isEmpty
                          ? 'No UK postcode on this order — tap Navigate for Maps'
                          : 'Postcode ${job.postcode} — tap Navigate for directions',
                      style: DC.t(12.5, color: Colors.white70, w: FontWeight.w600),
                    ),
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          sliver: SliverList.list(children: [
            Row(children: [TypeBadge(job), const SizedBox(width: 8), StatusPill(job), const Spacer(), if (d != null) Text('${Geo.km(d)} away', style: DC.t(13, color: DC.mut, w: FontWeight.w700))]),
            const SizedBox(height: 12),
            Text(job.customerName.isEmpty ? 'Customer' : job.customerName, style: DC.h(26)),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                RoundAction(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  onTap: () async {
                    final ok = await callCustomer(job);
                    if (!ok && context.mounted) toast(context, 'No customer phone number on this order');
                  },
                ),
                RoundAction(
                  icon: Icons.sms_rounded,
                  label: 'Text',
                  color: DC.blue,
                  onTap: () async {
                    final ok = await textCustomer(job, 'Hi ${job.firstName}, this is your DryClean Plus driver. ');
                    if (!ok && context.mounted) toast(context, 'No customer phone number on this order');
                  },
                ),
                RoundAction(icon: Icons.navigation_rounded, label: 'Navigate', color: DC.emerald, onTap: () => navigateTo(job)),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(children: [
                InfoRow(icon: Icons.place_outlined, label: 'Address', value: job.fullAddress),
                if (job.phone.isNotEmpty) InfoRow(icon: Icons.phone_outlined, label: 'Customer phone', value: job.phone),
                InfoRow(icon: Icons.schedule_rounded, label: job.isPickup ? 'Collection slot' : 'Delivery slot', value: job.slot.isEmpty ? 'Any time today' : '${job.date.isNotEmpty ? '${job.date} · ' : ''}${job.slot}'),
                if (job.handoff.isNotEmpty) InfoRow(icon: Icons.handshake_outlined, label: 'Handover', value: job.handoff),
                if (job.notes.isNotEmpty) InfoRow(icon: Icons.sticky_note_2_outlined, label: 'Notes from customer', value: job.notes),
              ]),
            ),
            if (job.services.isNotEmpty) ...[
              const SectionTitle('Services'),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in job.services)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: DC.mint, borderRadius: BorderRadius.circular(99)),
                        child: Text(s, style: DC.t(13.5, color: DC.emerald2, w: FontWeight.w800)),
                      ),
                  ]),
                  if (job.items.isEmpty && job.isPickup) ...[
                    const SizedBox(height: 10),
                    Text('Bag order — items are counted at the facility.', style: DC.t(12.5, color: DC.forest, w: FontWeight.w600)),
                  ],
                ]),
              ),
            ],
            if (job.items.isNotEmpty) ...[
              const SectionTitle('Items'),
              AppCard(
                child: Column(children: [
                  for (final i in job.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: DC.mint, borderRadius: BorderRadius.circular(9)),
                          child: Text('${i.qty}×', style: DC.t(12.5, color: DC.emerald2, w: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(i.name, style: DC.t(14.5, w: FontWeight.w700))),
                      ]),
                    ),
                  if (job.bags > 0) ...[
                    const Divider(height: 22),
                    Row(children: [
                      const Icon(Icons.shopping_bag_outlined, size: 19, color: DC.forest),
                      const SizedBox(width: 8),
                      Text('${job.bags} bag${job.bags == 1 ? '' : 's'}${job.bagTags.isNotEmpty ? ' · ${job.bagTags.join(', ')}' : ''}', style: DC.t(13.5, w: FontWeight.w700)),
                    ]),
                  ],
                ]),
              ),
            ],
            if (!job.isPickup && job.amountDue > 0) ...[
              const SectionTitle('Payment'),
              AppCard(
                color: DC.amberSoft,
                border: const Color(0xFFFDE68A),
                child: Row(children: [
                  const IconTile(Icons.payments_outlined, bg: Colors.white, fg: DC.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Collect £${job.amountDue.toStringAsFixed(2)}', style: DC.h(20, color: const Color(0xFF78350F))),
                      Text(job.paymentMethod.contains('cash') ? 'Customer chose cash' : 'Customer chose card on delivery', style: DC.t(13, color: const Color(0xFF92400E))),
                    ]),
                  ),
                ]),
              ),
            ],
            if (job.isDone) ...[
              const SizedBox(height: 16),
              AppCard(
                color: job.status == JobStatus.completed ? DC.mint : DC.redSoft,
                child: Row(children: [
                  Icon(job.status == JobStatus.completed ? Icons.check_circle_rounded : Icons.cancel_rounded, color: job.status == JobStatus.completed ? DC.emerald : DC.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(job.status == JobStatus.completed ? (job.isPickup ? 'Collected — ${job.bags} bag(s)' : 'Delivered') : 'Not completed: ${job.failReason ?? ''}', style: DC.t(14.5, w: FontWeight.w800))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
      bottomSheet: job.isDone ? null : _Actions(job: job),
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({required this.job});
  final Job job;
  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() f) async {
    setState(() => _busy = true);
    final err = await f().catchError((e) => 'Something went wrong: $e');
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) toast(context, err);
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final s = context.read<AppState>();
    final pad = MediaQuery.paddingOf(context).bottom;
    final Widget main = switch (j.status) {
      JobStatus.assigned => Btn('Start trip', icon: Icons.play_arrow_rounded, busy: _busy, onTap: () {
            final nav = Navigator.of(context);
            _run(() async {
              final err = await s.startTrip(j);
              if (err == null) nav.push(MaterialPageRoute(builder: (_) => TripScreen(jobId: j.id)));
              return err;
            });
          }),
      JobStatus.enRoute => Row(children: [
          Expanded(child: Btn('Trip map', icon: Icons.map_outlined, kind: BtnKind.light, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(jobId: j.id))))),
          const SizedBox(width: 10),
          Expanded(child: Btn("I'm here", icon: Icons.where_to_vote_rounded, busy: _busy, onTap: () => _run(() async {
                await s.arrived(j);
                return null;
              }))),
        ]),
      _ => Btn(j.isPickup ? 'Collect bags' : 'Hand over & finish', icon: j.isPickup ? Icons.qr_code_scanner_rounded : Icons.inventory_2_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(jobId: j.id)))),
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad),
      decoration: BoxDecoration(color: Colors.white, border: const Border(top: BorderSide(color: DC.line)), boxShadow: DC.shadow(.12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        main,
        TextButton(
          onPressed: () => showFailSheet(context, j),
          child: Text("Can't complete this ${j.isPickup ? 'pickup' : 'delivery'}", style: DC.t(13.5, color: DC.red, w: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Failed visit: reason + optional photo of the door.
Future<void> showFailSheet(BuildContext context, Job job) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FailSheet(job: job),
    );

class _FailSheet extends StatefulWidget {
  const _FailSheet({required this.job});
  final Job job;
  @override
  State<_FailSheet> createState() => _FailSheetState();
}

class _FailSheetState extends State<_FailSheet> {
  static const reasons = ['Customer not home', 'No access to the building', 'Wrong or incomplete address', 'Customer cancelled at the door', 'Other'];
  String? _reason;
  final _note = TextEditingController();
  XFile? _photo;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text("Why can't you complete it?", style: DC.h(21)),
          const SizedBox(height: 6),
          Text('The customer is told straight away and can pick a new slot.', style: DC.t(13.5, color: DC.mut, w: FontWeight.w500)),
          const SizedBox(height: 12),
          for (final r in reasons)
            ListTile(
              onTap: () => setState(() => _reason = r),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_reason == r ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _reason == r ? DC.forest : DC.mut),
              title: Text(r, style: DC.t(14.5, w: FontWeight.w700)),
            ),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
              if (x != null) setState(() => _photo = x);
            },
            icon: Icon(_photo == null ? Icons.photo_camera_outlined : Icons.check_circle_rounded, color: _photo == null ? DC.forest : DC.emerald),
            label: Text(_photo == null ? 'Photo of the door (recommended)' : 'Photo added', style: DC.t(14, w: FontWeight.w700)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 14),
          Btn('Mark as not completed', kind: BtnKind.danger, busy: _busy, onTap: _reason == null
              ? null
              : () async {
                  setState(() => _busy = true);
                  final reason = [_reason!, _note.text.trim()].where((e) => e.isNotEmpty).join(' — ');
                  await context.read<AppState>().fail(widget.job, reason, photo: _photo == null ? null : await _photo!.readAsBytes());
                  if (context.mounted) Navigator.of(context)..pop()..popUntil((r) => r.isFirst);
                }),
        ]),
      );
}
