import 'package:flutter/material.dart';

import '../models.dart';
import '../services/location_tracker.dart';
import '../theme.dart';

/// The DryClean Plus "DC" organic shape.
class DCLogo extends StatelessWidget {
  const DCLogo({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) {
    final w = size, h = size;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.elliptical(w * .3, h * .3),
          topRight: Radius.elliptical(w * .7, h * .3),
          bottomRight: Radius.elliptical(w * .7, h * .7),
          bottomLeft: Radius.elliptical(w * .3, h * .7),
        ),
        border: Border.all(color: const Color(0x734ADE80), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF064E3B).withValues(alpha: .4), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'DC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .34, letterSpacing: -.5)),
          TextSpan(text: '+', style: TextStyle(color: const Color(0xFFFF4D4F), fontWeight: FontWeight.w900, fontSize: size * .3)),
        ]),
      ),
    );
  }
}

enum BtnKind { gold, dark, light, danger }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onTap, this.icon, this.kind = BtnKind.gold, this.busy = false, this.expand = true, this.height = 56});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BtnKind kind;
  final bool busy;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BtnKind.gold => (DC.gold, DC.forest, Colors.transparent),
      BtnKind.dark => (DC.forest, Colors.white, Colors.transparent),
      BtnKind.light => (Colors.white, DC.ink, DC.line),
      BtnKind.danger => (DC.redSoft, DC.red, const Color(0xFFFECACA)),
    };
    final disabled = onTap == null || busy;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: DC.t(16, color: fg, w: FontWeight.w800))),
        ],
      ],
    );
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: disabled ? null : onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.5),
              boxShadow: kind == BtnKind.gold ? [BoxShadow(color: const Color(0xFFCA8A04).withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)] : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = Colors.white, this.border});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? border;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border ?? const Color(0xFFE6ECE8)),
              boxShadow: DC.shadow(.08),
            ),
            child: child,
          ),
        ),
      );
}

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.job, {super.key});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final pickup = job.isPickup;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: pickup ? DC.gold : DC.mint2, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pickup ? Icons.north_east_rounded : Icons.south_west_rounded, size: 14, color: pickup ? DC.forest : DC.emerald2),
        const SizedBox(width: 4),
        Text(pickup ? 'PICKUP' : 'DELIVERY', style: DC.t(11, color: pickup ? DC.forest : DC.emerald2, w: FontWeight.w800).copyWith(letterSpacing: .8)),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.job, {super.key});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (job.status) {
      JobStatus.enRoute => ('On the way', DC.blueSoft, DC.blue),
      JobStatus.arrived => ('Arrived', DC.amberSoft, DC.amber),
      JobStatus.completed => (job.isPickup ? 'Collected' : 'Delivered', DC.mint, DC.emerald2),
      JobStatus.failed => ('Not completed', DC.redSoft, DC.red),
      _ => ('Scheduled', const Color(0xFFF1F5F9), DC.mut),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: DC.t(12, color: fg, w: FontWeight.w800)),
      ]),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.bg = DC.mint, this.fg = DC.forest, this.size = 44});
  final IconData icon;
  final Color bg, fg;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .32)),
        child: Icon(icon, color: fg, size: size * .5),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [Expanded(child: Text(text, style: DC.h(19))), ?trailing]),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: DC.t(10.5, color: DC.mut, w: FontWeight.w800).copyWith(letterSpacing: .9)),
              const SizedBox(height: 3),
              Text(value, style: DC.t(15, w: FontWeight.w700, height: 1.35)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.label, required this.onTap, this.color = DC.forest});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: DC.t(12, w: FontWeight.w700)),
          ]),
        ),
      );
}

void toast(BuildContext context, String msg) {
  // GPS problems get a button that opens the right phone setting
  if (LocationTracker.isGpsProblem(msg)) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.location_off_rounded, size: 46, color: Color(0xFFDC2626)),
            const SizedBox(height: 10),
            Text(msg == LocationTracker.msgGpsOff ? 'Turn on GPS' : 'Allow location', textAlign: TextAlign.center, style: DC.h(21)),
            const SizedBox(height: 6),
            Text(msg, textAlign: TextAlign.center, style: DC.t(14, color: DC.mut)),
            const SizedBox(height: 6),
            Text('Customers and dispatch follow your van on the map while you’re on the way.', textAlign: TextAlign.center, style: DC.t(13, color: DC.mut)),
            const SizedBox(height: 16),
            Btn(msg == LocationTracker.msgGpsOff ? 'Open location settings' : 'Open app settings', icon: Icons.settings_rounded, onTap: () {
              Navigator.pop(ctx);
              LocationTracker.openFix(msg);
            }),
          ]),
        ),
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
