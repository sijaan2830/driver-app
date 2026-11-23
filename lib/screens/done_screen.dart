import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'job_screen.dart';

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final job = s.byId(jobId);
    final next = s.remaining.isEmpty ? null : s.remaining.first;
    final pickup = job?.isPickup ?? true;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF34D399), DC.forest], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: DC.shadow(.45),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 66),
              ),
            ),
            const SizedBox(height: 26),
            Text(pickup ? 'Collection confirmed!' : 'Delivered!', style: DC.h(30), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              job == null ? '' : '${job.customerName} · #${job.orderId}\n${pickup ? '${job.bags} bag(s) on board. ${job.firstName} has been notified.' : '${job.firstName} has been notified. Thank you!'}',
              textAlign: TextAlign.center,
              style: DC.t(15, color: DC.mut, w: FontWeight.w600, height: 1.5),
            ),
            const Spacer(),
            if (next != null) ...[
              AppCard(
                child: Row(children: [
                  TypeBadge(next),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Next: ${next.customerName}', style: DC.t(15, w: FontWeight.w800)),
                      Text('${next.slot} · ${next.postcode}', style: DC.t(13, color: DC.mut)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Btn('Go to next job', icon: Icons.arrow_forward_rounded, onTap: () {
                Navigator.popUntil(context, (r) => r.isFirst);
                Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(jobId: next.id)));
              }),
              const SizedBox(height: 10),
            ],
            Btn(next == null ? 'All done — back to route' : 'Back to route', kind: next == null ? BtnKind.gold : BtnKind.light, onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
          ]),
        ),
      ),
    );
  }
}
