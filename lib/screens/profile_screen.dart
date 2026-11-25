import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final d = s.driver;
    final failed = s.jobs.where((j) => j.status == JobStatus.failed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('My shift')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(radius: 32, backgroundColor: DC.forest, child: Text(d?.initials ?? 'D', style: DC.h(22, color: DC.gold))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d?.name ?? 'Driver', style: DC.h(22)),
                const SizedBox(height: 4),
                if ((d?.vehicle ?? '').isNotEmpty || (d?.reg ?? '').isNotEmpty)
                  Text([d?.vehicle, d?.reg].where((e) => (e ?? '').isNotEmpty).join(' · '), style: DC.t(13.5, color: DC.mut)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Today'),
        Row(children: [
          _Num('${s.doneOf('pickup')}', 'Collected', DC.amber),
          const SizedBox(width: 10),
          _Num('${s.doneOf('delivery')}', 'Delivered', DC.emerald),
          const SizedBox(width: 10),
          _Num('$failed', 'Not done', DC.red),
        ]),
        const SectionTitle('Shift'),
        AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: DC.mint, child: Icon(Icons.my_location_rounded, color: DC.emerald)),
            title: Text('Active on shift', style: DC.t(15, w: FontWeight.w800)),
            subtitle: Text('Location shares automatically while you are on a trip.', style: DC.t(12.5, color: DC.mut)),
          ),
        ),
        const SizedBox(height: 26),
        Btn('Sign out', icon: Icons.logout_rounded, kind: BtnKind.danger, onTap: () async {
          await context.read<AppState>().signOut();
          if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
        }),
      ]),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Text(value, style: DC.h(28, color: color)),
            const SizedBox(height: 2),
            Text(label, style: DC.t(12.5, color: DC.mut)),
          ]),
        ),
      );
}
