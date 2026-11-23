import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/geo.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/launch.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';
import 'job_screen.dart';
import 'scan_screen.dart';

/// Live trip: map follows the van, ETA updates, auto-arrive near the stop.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final job = s.byId(jobId);
    if (job == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final d = s.distanceTo(job);
    final arrived = job.status == JobStatus.arrived;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: RouteMap(me: s.me, heading: s.heading, stops: [job], focus: job, follow: s.me != null && !arrived, line: true)),
        // top bar
        Positioned(
          top: top + 10,
          left: 14,
          right: 14,
          child: Row(children: [
            _Fab(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: DC.shadow(.25)),
                child: Row(children: [
                  TypeBadge(job),
                  const SizedBox(width: 10),
                  Expanded(child: Text('#${job.orderId}', style: DC.t(14, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  Container(width: 9, height: 9, decoration: const BoxDecoration(color: DC.emerald, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Live', style: DC.t(12.5, color: DC.emerald2, w: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
        ),
        // bottom panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 14 + bottom),
            decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(26)), boxShadow: DC.shadow(.3)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: arrived ? DC.amberSoft : DC.mint, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Text(arrived ? 'HERE' : (d == null ? '—' : '${Geo.etaMinutes(d)}'), style: DC.h(arrived ? 20 : 28, color: arrived ? DC.amber : DC.forest)),
                    Text(arrived ? 'arrived' : 'min', style: DC.t(12, color: arrived ? DC.amber : DC.emerald2, w: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job.customerName, style: DC.h(21)),
                    const SizedBox(height: 3),
                    Text(job.fullAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: DC.t(13.5, color: DC.mut, w: FontWeight.w600)),
                    if (d != null && !arrived) Text('${Geo.km(d)} away · ${job.slot}', style: DC.t(12.5, color: DC.forest, w: FontWeight.w700)),
                  ]),
                ),
              ]),
              if (job.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('“${job.notes}”', style: DC.t(13.5, color: const Color(0xFF78350F), w: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              if (arrived)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.front_hand_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ARRIVED · STOP & PARK HERE', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E), fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              job.fullAddress,
                              style: const TextStyle(color: Color(0xFF78350F), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Row(children: [
                Expanded(child: Btn('Navigate', icon: Icons.navigation_rounded, kind: BtnKind.dark, height: 52, onTap: () => navigateTo(job))),
                const SizedBox(width: 10),
                _Fab(icon: Icons.call_rounded, onTap: () => callCustomer(job), size: 52),
                const SizedBox(width: 10),
                _Fab(icon: Icons.info_outline_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(jobId: job.id))), size: 52),
              ]),
              const SizedBox(height: 10),
              if (arrived)
                Btn(job.isPickup ? 'Collect bags' : 'Hand over & finish', icon: job.isPickup ? Icons.qr_code_scanner_rounded : Icons.inventory_2_outlined,
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScanScreen(jobId: job.id))))
              else
                Btn("I'm here", icon: Icons.where_to_vote_rounded, onTap: () => context.read<AppState>().arrived(job)),
              if (!arrived)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Arrival is marked automatically when you are within 100 m.', textAlign: TextAlign.center, style: DC.t(12, color: DC.mut, w: FontWeight.w500)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.icon, required this.onTap, this.size = 46});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: DC.line)),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: DC.forest)),
        ),
      );
}
