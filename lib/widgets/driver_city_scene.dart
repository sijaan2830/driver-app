import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The exact signature animated City & DC+ Delivery Van scene from DryClean Plus.
/// Features:
/// - Deep twilight gradient sky with twinkling stars
/// - London skyline silhouettes: Big Ben, rotating London Eye, and urban high-rises
/// - Asphalt roadway with animated dashed center line, curb, and railings
/// - The iconic DryClean Plus delivery van:
///   * Metallic white/silver body with aerodynamic cabin
///   * Tinted curved windshield (#225ED6)
///   * Teal corporate stripe (#0F9F90)
///   * Organic DC+ pick badge (#071F14 badge with 'DC' in white, '+' in red)
///   * Cursive Satisfy "DrycleanPlus+" brand typography
///   * "Premium care · Delivered to you" tagline
///   * Forward-projecting conical headlight beam with road illumination pool
///   * Glowing bulb, lens flare, and red taillight
///   * 5-spoke rotating wheels with chrome rims and hubcaps
///   * Trailing waving banner / flag with dynamic wave motion
class DriverCityScene extends StatefulWidget {
  final double height;
  final bool animateDriveOut;
  final bool transparentBg;

  const DriverCityScene({
    super.key,
    this.height = 190,
    this.animateDriveOut = false,
    this.transparentBg = true,
  });

  @override
  State<DriverCityScene> createState() => _DriverCitySceneState();
}

class _DriverCitySceneState extends State<DriverCityScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 360),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double tMs = _controller.value * 360000.0;
              final double farT = (tMs % 40000.0) / 40000.0;
              final double midT = (tMs % 24000.0) / 24000.0;
              final double dashT = (tMs % 900.0) / 900.0;
              final double wheelAngle = ((tMs % 700.0) / 700.0) * 2.0 * math.pi;
              final double vanProgress = (tMs % 9000.0) / 9000.0;

              return CustomPaint(
                size: Size(double.infinity, widget.height),
                painter: _DriverCityPainter(
                  farT: farT,
                  midT: midT,
                  dashT: dashT,
                  wheelAngle: wheelAngle,
                  vanProgress: vanProgress,
                  isSpeeding: widget.animateDriveOut,
                  transparentBg: widget.transparentBg,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DriverCityPainter extends CustomPainter {
  final double farT;
  final double midT;
  final double dashT;
  final double wheelAngle;
  final double vanProgress;
  final bool isSpeeding;
  final bool transparentBg;

  // Cached TextPainters to eliminate per-frame layout overhead & memory thrashing
  static TextPainter? _cachedVanBrand;
  static TextPainter get _vanBrandTp {
    try {
      return _cachedVanBrand ??= TextPainter(
        text: TextSpan(
          style: GoogleFonts.satisfy(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
          children: const [
            TextSpan(text: 'Dryclean', style: TextStyle(color: Color(0xFF0B2545))),
            TextSpan(text: 'Plus', style: TextStyle(color: Color(0xFFE5262D))),
            TextSpan(text: '+', style: TextStyle(color: Color(0xFFE5262D), fontSize: 13)),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    } catch (_) {
      return TextPainter(
        text: const TextSpan(
          text: 'DrycleanPlus+',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  static TextPainter? _cachedSub;
  static TextPainter get _subTp {
    try {
      return _cachedSub ??= TextPainter(
        text: const TextSpan(
          text: 'Premium care · Delivered to you',
          style: TextStyle(
            fontSize: 5.2,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.05,
            color: Color(0xFF1550E8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
    } catch (_) {
      return TextPainter(
        text: const TextSpan(
          text: 'Premium care',
          style: TextStyle(fontSize: 5.2, color: Color(0xFF1550E8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  static TextPainter? _cachedBadge;
  static TextPainter get _badgeTp {
    try {
      return _cachedBadge ??= TextPainter(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 7.7,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
          children: const [
            TextSpan(text: 'DC', style: TextStyle(color: Colors.white)),
            TextSpan(text: '+', style: TextStyle(color: Color(0xFFE5262D))),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    } catch (_) {
      return TextPainter(
        text: const TextSpan(
          text: 'DC+',
          style: TextStyle(fontSize: 7.7, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  static TextPainter? _cachedFlag;
  static TextPainter get _flagTp {
    try {
      return _cachedFlag ??= TextPainter(
        text: const TextSpan(
          text: 'DC+',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    } catch (_) {
      return TextPainter(
        text: const TextSpan(
          text: 'DC+',
          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  _DriverCityPainter({
    required this.farT,
    required this.midT,
    required this.dashT,
    required this.wheelAngle,
    required this.vanProgress,
    required this.isSpeeding,
    this.transparentBg = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final w = size.width;
      final h = size.height;
      if (w <= 0 || h <= 0) return;

      // Design canvas coordinate system: 400 x 200 base
      final scale = h / 200.0;
      canvas.save();
      canvas.scale(scale, scale);
      final virtualW = w / scale;

      // 1. Twilight sky gradient (only when not transparent)
      if (!transparentBg) {
        final skyPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF040E2C), Color(0xFF092265), Color(0xFF0D328F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, virtualW, 200));
        canvas.drawRect(Rect.fromLTWH(0, 0, virtualW, 200), skyPaint);
      }

      // 2. Stars
      _drawStars(canvas, virtualW);

      // 3. Far London Skyline (Big Ben, London Eye, Skyscrapers)
      _drawFarSkyline(canvas, virtualW);

      // 4. Asphalt Road, Curb & Lane Markings
      _drawRoad(canvas, virtualW);

      // 5. The iconic DC+ Delivery Van with Headlights, Flag & Brand
      _drawIconicVan(canvas, virtualW);

      canvas.restore();
    } catch (e) {
      debugPrint('[DriverCityScene] paint error: $e');
    }
  }

  void _drawStars(Canvas canvas, double virtualW) {
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.65);
    const starList = [
      [24.0, 18.0, 1.2],
      [75.0, 32.0, 1.5],
      [140.0, 15.0, 1.0],
      [195.0, 28.0, 1.6],
      [260.0, 14.0, 1.1],
      [315.0, 34.0, 1.4],
      [370.0, 20.0, 1.2],
      [420.0, 26.0, 1.5],
      [480.0, 16.0, 1.0],
    ];
    for (final s in starList) {
      final double x = (s[0] - midT * 20.0) % (virtualW + 40) - 20;
      canvas.drawCircle(Offset(x, s[1]), s[2], starPaint);
    }
  }

  void _drawFarSkyline(Canvas canvas, double virtualW) {
    const double baselineY = 148.0;
    final bldgPaint = Paint()..color = const Color(0xFF163273).withValues(alpha: 0.45);
    final shift = -farT * 320.0;

    for (int i = -1; i < (virtualW / 320.0).ceil() + 1; i++) {
      canvas.save();
      canvas.translate(shift + i * 320.0, baselineY);

      // Building blocks
      const fb = [
        [4.0, 22.0, 42.0],
        [28.0, 14.0, 58.0],
        [68.0, 20.0, 48.0],
        [90.0, 24.0, 64.0],
        [118.0, 18.0, 40.0],
        [140.0, 26.0, 55.0],
        [170.0, 20.0, 78.0],
        [194.0, 24.0, 46.0],
      ];
      for (final b in fb) {
        canvas.drawRect(Rect.fromLTWH(b[0], -b[2], b[1], b[2]), bldgPaint);
      }

      // Big Ben Spire
      canvas.drawRect(const Rect.fromLTWH(44, -110, 14, 110), bldgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(41, -110, 20, 20), const Radius.circular(2)), bldgPaint);
      final spirePath = Path()
        ..moveTo(41, -110)
        ..lineTo(51, -135)
        ..lineTo(61, -110)
        ..close();
      canvas.drawPath(spirePath, bldgPaint);
      canvas.drawRect(const Rect.fromLTWH(50, -148, 2.5, 13), bldgPaint);

      // Clock face
      final clockPaint = Paint()..color = const Color(0xFFFFE885).withValues(alpha: 0.4);
      canvas.drawCircle(const Offset(51, -100), 4.5, clockPaint);

      // London Eye
      canvas.save();
      canvas.translate(260.0, -48.0);
      final eyeStroke = Paint()
        ..color = const Color(0xFF1E429B).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Legs
      canvas.drawLine(const Offset(0, 0), const Offset(-12, 48), eyeStroke);
      canvas.drawLine(const Offset(0, 0), const Offset(12, 48), eyeStroke);

      // Wheel
      canvas.drawCircle(Offset.zero, 36, eyeStroke);
      canvas.drawCircle(Offset.zero, 30, eyeStroke..strokeWidth = 1.0);
      for (int s = 0; s < 6; s++) {
        final rad = s * math.pi / 3.0;
        canvas.drawLine(
          Offset(math.cos(rad) * 36, math.sin(rad) * 36),
          Offset(-math.cos(rad) * 36, -math.sin(rad) * 36),
          eyeStroke,
        );
      }
      canvas.restore();

      canvas.restore();
    }
  }

  void _drawRoad(Canvas canvas, double virtualW) {
    const double roadTop = 152.0;
    const double roadBottom = 200.0;

    // Curb edge line
    canvas.drawRect(Rect.fromLTWH(0, roadTop, virtualW, 4), Paint()..color = const Color(0xFF3265D6));

    // Asphalt surface
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop + 4, virtualW, roadBottom - roadTop - 4),
      Paint()..color = const Color(0xFF09193D),
    );

    // Animated dashed white road line
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final dashShift = -dashT * 48.0;
    for (double x = dashShift - 40; x < virtualW + 40; x += 44.0) {
      canvas.drawLine(Offset(x, 178), Offset(x + 24, 178), dashPaint);
    }
  }

  void _drawIconicVan(Canvas canvas, double virtualW) {
    canvas.save();

    // Van moves continuously across screen or stays centered with cruising offset
    final double totalSpan = virtualW + 220.0;
    final double vanX = -110.0 + (totalSpan * vanProgress);
    const double vanY = 120.0;
    const double vanScale = 0.58;

    canvas.translate(vanX, vanY);
    canvas.scale(vanScale, vanScale);

    // Waving Flag trailing behind van
    _drawWavingFlag(canvas);

    // Ground Shadow under van
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(98, 92), width: 210, height: 11),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Aerodynamic trailing ripple lines
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double wavePhase = dashT * 2.0 * math.pi;
    final path1 = Path()
      ..moveTo(-10, 48)
      ..quadraticBezierTo(-28, 48 + math.sin(wavePhase) * 2.5, -50, 48);
    canvas.drawPath(path1, wavePaint);

    final path2 = Path()
      ..moveTo(-15, 68)
      ..quadraticBezierTo(-35, 68 + math.cos(wavePhase) * 2.5, -60, 68);
    canvas.drawPath(path2, wavePaint);

    // Van Body Gradient (Metallic White to Soft Silver Blue)
    final vanBodyGradient = const LinearGradient(
      colors: [Colors.white, Color(0xFFCBD6EB)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final vanPaint = Paint()
      ..shader = vanBodyGradient.createShader(const Rect.fromLTWH(0, 0, 190, 80));

    // Cargo Box
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 125, 78), const Radius.circular(10)),
      vanPaint,
    );

    // Driver Cab
    final cabPath = Path()
      ..moveTo(125, 16)
      ..lineTo(147, 16)
      ..cubicTo(158, 16, 177, 42, 185, 50)
      ..lineTo(185, 78)
      ..lineTo(125, 78)
      ..close();
    canvas.drawPath(cabPath, vanPaint);

    // Front Bumper
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(180, 68, 10, 10), const Radius.circular(3)),
      Paint()..color = const Color(0xFF8EA3C7),
    );

    // Windshield (Curved blue tinted glass)
    final wsPath = Path()
      ..moveTo(133, 22)
      ..lineTo(146, 22)
      ..cubicTo(153, 22, 167, 40, 172, 46)
      ..lineTo(133, 46)
      ..close();
    canvas.drawPath(wsPath, Paint()..color = const Color(0xFF225ED6));

    // Side Door Seam
    canvas.drawLine(
      const Offset(125, 16),
      const Offset(125, 78),
      Paint()
        ..color = const Color(0xFFBAC7DF)
        ..strokeWidth = 1.2,
    );

    // Vibrant Teal Stripe (#0F9F90)
    canvas.drawRect(const Rect.fromLTWH(0, 50, 185, 6), Paint()..color = const Color(0xFF0F9F90));

    // Organic DC+ Pick Badge on Van Side
    _drawVanPickBadge(canvas, const Offset(14, 18), 22);

    // Cursive "DrycleanPlus+" Brand & Tagline (using cached painters)
    _vanBrandTp.paint(canvas, const Offset(38, 16));
    _subTp.paint(canvas, const Offset(38, 34));

    // Illuminated Forward Headlight Beam Cone
    final beamPath = Path()
      ..moveTo(187, 62)
      ..lineTo(350, 22)
      ..lineTo(350, 114)
      ..lineTo(187, 72)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xB3FFF8C4), Color(0x55FFE885), Color(0x00FFE885)],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(const Rect.fromLTWH(187, 22, 163, 92)),
    );

    // Projected luminous pool on asphalt
    canvas.drawOval(
      const Rect.fromLTWH(204, 72, 130, 20),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x59FFE885), Color(0x00FFE885)],
        ).createShader(const Rect.fromLTWH(204, 72, 130, 20)),
    );

    // Radiant glowing headlight bulb & lens flare
    canvas.drawCircle(const Offset(187, 67), 9, Paint()..color = const Color(0x55FFE885));
    canvas.drawCircle(const Offset(187, 67), 5.5, Paint()..color = const Color(0xFFFFFAEB));
    canvas.drawCircle(const Offset(187, 67), 3.0, Paint()..color = Colors.white);

    // Taillight
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-2, 50, 4, 9), const Radius.circular(1)),
      Paint()..color = const Color(0xFFFF5A4D),
    );

    // 5-Spoke Rotating Wheels
    _drawWheel(canvas, const Offset(42, 78));
    _drawWheel(canvas, const Offset(150, 78));

    canvas.restore();
  }

  void _drawVanPickBadge(Canvas canvas, Offset offset, double size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final w = size;
    final h = size;

    final path = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, w, h),
        topLeft: Radius.elliptical(w * 0.30, h * 0.30),
        topRight: Radius.elliptical(w * 0.70, h * 0.30),
        bottomRight: Radius.elliptical(w * 0.70, h * 0.70),
        bottomLeft: Radius.elliptical(w * 0.30, h * 0.70),
      ));

    canvas.drawPath(path, Paint()..color = const Color(0xFF071F14));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _badgeTp.paint(
      canvas,
      Offset((w - _badgeTp.width) / 2.0, (h - _badgeTp.height) / 2.0),
    );

    canvas.restore();
  }

  void _drawWheel(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.drawCircle(Offset.zero, 18, Paint()..color = const Color(0xFF1B2333));
    canvas.drawCircle(Offset.zero, 12, Paint()..color = const Color(0xFFC7D3E8));
    canvas.drawCircle(Offset.zero, 6, Paint()..color = const Color(0xFF0B2545));

    canvas.rotate(wheelAngle);
    final spokePaint = Paint()
      ..color = const Color(0xFF6B7E9F)
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      final double rad = i * 2.0 * math.pi / 5.0;
      canvas.drawLine(Offset.zero, Offset(math.cos(rad) * 12, math.sin(rad) * 12), spokePaint);
    }

    canvas.restore();
  }

  void _drawWavingFlag(Canvas canvas) {
    canvas.save();

    final double speedFactor = isSpeeding ? 2.4 : 1.0;
    final double animPhase = (midT * 8.5 * 2.0 * math.pi) * speedFactor;

    // Chrome Flag Pole
    final polePaint = Paint()
      ..color = const Color(0xFFD4DEEE)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 16), const Offset(0, 38), polePaint);

    const double startY = 15.0;
    const double flagLength = 58.0;
    const double flagHeight = 20.0;
    const int segments = 18;

    final List<Offset> topPoints = [];
    final List<Offset> botPoints = [];

    for (int i = 0; i <= segments; i++) {
      final double progress = i / segments.toDouble();
      final double x = -progress * flagLength;
      final double wave1 = math.sin(animPhase - progress * 1.8 * math.pi) * (1.2 * progress * speedFactor);
      final double wave2 = math.cos(animPhase * 0.8 - progress * 2.6 * math.pi) * (0.5 * progress * speedFactor);
      final double totalWave = wave1 + wave2;

      topPoints.add(Offset(x, startY + totalWave));
      botPoints.add(Offset(x, startY + flagHeight + totalWave));
    }

    final flagPath = Path()..moveTo(topPoints.first.dx, topPoints.first.dy);
    for (int i = 1; i < topPoints.length; i++) {
      flagPath.lineTo(topPoints[i].dx, topPoints[i].dy);
    }
    for (int i = botPoints.length - 1; i >= 0; i--) {
      flagPath.lineTo(botPoints[i].dx, botPoints[i].dy);
    }
    flagPath.close();

    // Red flag banner
    canvas.drawPath(flagPath, Paint()..color = const Color(0xFFE5262D));

    // DC+ label on flag
    final double midIdx = (segments / 2.0).floorToDouble();
    final Offset flagCenter = Offset(
      topPoints[midIdx.toInt()].dx,
      (topPoints[midIdx.toInt()].dy + botPoints[midIdx.toInt()].dy) / 2.0,
    );

    canvas.save();
    canvas.translate(flagCenter.dx, flagCenter.dy);
    _flagTp.paint(canvas, Offset(-_flagTp.width / 2.0, -_flagTp.height / 2.0));
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DriverCityPainter oldDelegate) {
    return oldDelegate.farT != farT ||
        oldDelegate.midT != midT ||
        oldDelegate.dashT != dashT ||
        oldDelegate.wheelAngle != wheelAngle ||
        oldDelegate.vanProgress != vanProgress ||
        oldDelegate.isSpeeding != isSpeeding ||
        oldDelegate.transparentBg != transparentBg;
  }
}
