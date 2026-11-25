import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/geo.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';
import 'job_screen.dart';
import 'profile_screen.dart';
import 'trip_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final notice = s.takeNotice();
    if (notice != null) WidgetsBinding.instance.addPostFrameCallback((_) => toast(context, notice));
    final next = s.next;
    final later = s.remaining.where((j) => j.id != next?.id).toList();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: CustomScrollView(slivers: [
        // ------------------------------------------------ header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, top + 14, 20, 64),
            decoration: const BoxDecoration(gradient: DC.heroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const DCLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting(), style: DC.t(13, color: DC.mint2)),
                    Text(s.driver?.firstName ?? 'Driver', style: DC.h(22, color: Colors.white)),
                  ]),
                ),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(radius: 21, backgroundColor: DC.gold, child: Text(s.driver?.initials ?? 'D', style: DC.h(15, color: DC.forest))),
                ),
              ]),
              const SizedBox(height: 14),
              _LiveLine(online: s.online, hasFix: s.me != null, lastSent: s.lastSent, failing: s.sendFailing, gpsOff: s.gpsOff),
            ]),
          ),
        ),
        // ------------------------------------------------ stats
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _Stat(icon: Icons.route_rounded, value: '${s.remaining.length}', label: 'Stops left', color: DC.forest),
                const SizedBox(width: 10),
                _Stat(icon: Icons.north_east_rounded, value: '${s.doneOf('pickup')}/${s.totalOf('pickup')}', label: 'Pickups', color: DC.amber),
                const SizedBox(width: 10),
                _Stat(icon: Icons.south_west_rounded, value: '${s.doneOf('delivery')}/${s.totalOf('delivery')}', label: 'Deliveries', color: DC.emerald),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          sliver: SliverList.list(children: [
            Transform.translate(
              offset: const Offset(0, -28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (next == null)
                  _Empty(hasAny: s.jobs.isNotEmpty)
                else ...[
                  SectionTitle(next.isActive ? 'Current job' : 'Up next'),
                  _NextCard(job: next),
                ],
                if (s.jobs.any((j) => j.hasGeo)) ...[
                  const SectionTitle('Route map'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(height: 200, child: RouteMap(me: s.me, heading: s.heading, stops: s.jobs, focus: next, interactive: false)),
                  ),
                ],
                if (later.isNotEmpty) ...[
                  SectionTitle('Later today', trailing: Text('${later.length} stops', style: DC.t(13, color: DC.mut))),
                  for (var i = 0; i < later.length; i++) _RouteTile(job: later[i], last: i == later.length - 1),
                ],
                if (s.completed.isNotEmpty) ...[
                  SectionTitle('Done', trailing: Text('${s.completed.length}', style: DC.t(13, color: DC.mut))),
                  for (final j in s.completed.reversed) _DoneTile(job: j),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Tells the driver their live GPS status (always online while signed in).
class _LiveLine extends StatelessWidget {
  const _LiveLine({required this.online, required this.hasFix, required this.lastSent, required this.failing, this.gpsOff = false});
  final bool online, hasFix, failing, gpsOff;
  final DateTime? lastSent;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color dot) = gpsOff
        ? (Icons.location_disabled_rounded, 'Tap here to allow location', const Color(0xFFFCA5A5))
        : failing
            ? (Icons.cloud_off_rounded, 'Reconnecting GPS…', const Color(0xFFFCA5A5))
            : !hasFix
                ? (Icons.gps_not_fixed_rounded, 'Connecting GPS…', DC.gold)
                : (Icons.my_location_rounded, lastSent == null ? 'Live GPS active' : 'Live GPS active · ${TimeOfDay.fromDateTime(lastSent!).format(context)}', const Color(0xFF4ADE80));
    final row = Row(children: [
      Icon(icon, size: 16, color: dot),
      const SizedBox(width: 7),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: DC.t(12.5, color: Colors.white, w: FontWeight.w700))),
    ]);
    return gpsOff || !online
        ? InkWell(
            onTap: () async {
              final err = await context.read<AppState>().setOnline(true);
              if (err != null && context.mounted) toast(context, err);
            },
            child: row,
          )
        : row;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon, bg: color.withValues(alpha: .1), fg: color, size: 34),
            const SizedBox(height: 10),
            Text(value, style: DC.h(22)),
            Text(label, style: DC.t(12, color: DC.mut)),
          ]),
        ),
      );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.distanceTo(job);
    return AppCard(
      padding: const EdgeInsets.all(18),
      border: job.isActive ? DC.emerald : null,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(jobId: job.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [TypeBadge(job), const SizedBox(width: 8), StatusPill(job), const Spacer(), Text('#${job.orderId}', style: DC.t(12, color: DC.mut))]),
        const SizedBox(height: 14),
        Text(job.customerName, style: DC.h(23)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.place_outlined, size: 17, color: DC.mut),
          const SizedBox(width: 4),
          Expanded(child: Text(job.fullAddress, style: DC.t(14, color: DC.mut, w: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _Chip(Icons.schedule_rounded, job.slot.isEmpty ? 'Any time' : job.slot),
          const SizedBox(width: 8),
          if (d != null) _Chip(Icons.directions_car_filled_outlined, '${Geo.km(d)} · ${Geo.etaMinutes(d)} min'),
        ]),
        if (job.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DC.amberSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.sticky_note_2_outlined, size: 18, color: DC.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(job.notes, style: DC.t(13.5, color: const Color(0xFF78350F), w: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        if (job.isActive)
          Btn('Open trip', icon: Icons.navigation_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(jobId: job.id))))
        else
          Btn('Start trip', icon: Icons.play_arrow_rounded, onTap: () async {
            final err = await context.read<AppState>().startTrip(job);
            if (!context.mounted) return;
            if (err != null) return toast(context, err);
            Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(jobId: job.id)));
          }),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: DC.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: DC.forest),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: DC.t(12.5, w: FontWeight.w700))),
          ]),
        ),
      );
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.job, required this.last});
  final Job job;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 34,
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: job.isPickup ? DC.amber : DC.emerald, width: 2.5)),
                alignment: Alignment.center,
                child: Text('${job.sequence}', style: DC.h(13, color: job.isPickup ? DC.amber : DC.emerald)),
              ),
              if (!last) Expanded(child: Container(width: 2, color: DC.line)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(jobId: job.id))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [TypeBadge(job), const SizedBox(width: 8), Text(job.slot, style: DC.t(12.5, color: DC.mut, w: FontWeight.w700))]),
                      const SizedBox(height: 8),
                      Text(job.customerName, style: DC.t(15.5, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(job.fullAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: DC.t(13, color: DC.mut, w: FontWeight.w500)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: DC.mut),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final ok = job.status == JobStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(jobId: job.id))),
        child: Row(children: [
          IconTile(ok ? Icons.check_rounded : Icons.close_rounded, bg: ok ? DC.mint : DC.redSoft, fg: ok ? DC.emerald : DC.red, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.customerName, style: DC.t(14.5, w: FontWeight.w800)),
              Text(ok ? '${job.isPickup ? 'Collected' : 'Delivered'} · #${job.orderId}' : (job.failReason ?? 'Not completed'),
                  style: DC.t(12.5, color: ok ? DC.mut : DC.red, w: FontWeight.w600)),
            ]),
          ),
          TypeBadge(job),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasAny});
  final bool hasAny;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: AppCard(
          padding: const EdgeInsets.all(26),
          child: Column(children: [
            IconTile(hasAny ? Icons.celebration_rounded : Icons.inbox_rounded, size: 64),
            const SizedBox(height: 14),
            Text(hasAny ? 'All done for today!' : 'No jobs yet today', style: DC.h(21)),
            const SizedBox(height: 6),
            Text(hasAny ? 'Great work. Head back to the hub.' : 'New jobs appear here as soon as dispatch assigns them to you.',
                textAlign: TextAlign.center, style: DC.t(14, color: DC.mut, w: FontWeight.w500, height: 1.45)),
          ]),
        ),
      );
}
