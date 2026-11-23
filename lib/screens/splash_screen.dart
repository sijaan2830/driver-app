import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/driver_city_scene.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _statusIdx = 0;
  Timer? _timer;

  static const _statusList = [
    'Connecting to Logistics Cloud...',
    'Loading Realtime GPS Routes...',
    'Driver Station Online & Ready',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        _statusIdx = (_statusIdx + 1) % _statusList.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF030A1F),
              Color(0xFF071B49),
              Color(0xFF0C2F88),
              Color(0xFF0E3FB5),
            ],
            stops: [0.0, 0.35, 0.70, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Dual Logo: Official App Icon + Hanger Logo Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1550E8).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _SplashHanger(width: 50),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const _SplashHanger(width: 66),
                ],
              ),
              const SizedBox(height: 20),

              // Brand Title
              Text(
                'DryClean Plus',
                style: GoogleFonts.satisfy(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Hub Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9F90).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF22E0B5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22E0B5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'DRIVER LOGISTICS HUB',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF22E0B5),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Realtime Route · Smart Pickup · Express Delivery',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFB5C9F2),
                ),
              ),

              const Spacer(flex: 2),

              // Exact Same Animated City & DC+ Delivery Van as Login/Onboarding
              const SizedBox(
                height: 130,
                width: double.infinity,
                child: DriverCityScene(
                  height: 130,
                  transparentBg: true,
                ),
              ),

              const SizedBox(height: 20),

              // Loading Spinner & Cycling Status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFFFFD75E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusList[_statusIdx],
                      key: ValueKey<int>(_statusIdx),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashHanger extends StatelessWidget {
  final double width;
  const _SplashHanger({required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * (66 / 80),
      child: CustomPaint(painter: _HangerPainterSplash()),
    );
  }
}

class _HangerPainterSplash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 80.0;
    canvas.save();
    canvas.scale(scale, scale);

    final hangerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(40, 26);
    path.lineTo(40, 18);
    path.arcToPoint(const Offset(46, 24), radius: const Radius.circular(6), clockwise: true);

    path.moveTo(40, 26);
    path.lineTo(12, 42);
    path.lineTo(68, 42);
    path.close();

    canvas.drawPath(path, hangerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DC',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(40 - (textPainter.width / 2), 43));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
