import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash-proof error handlers to ensure seamless operation on any mobile device
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[DriverApp] FlutterError: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[DriverApp] PlatformDispatcher caught error: $error');
    return true; // Prevents app termination / mobile browser reload
  };

  // Safe fallback UI if any widget throws an unhandled render error
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[DriverApp] ErrorWidget caught: ${details.exception}');
    return Material(
      color: const Color(0xFF030A1F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF38BDF8), size: 48),
              const SizedBox(height: 16),
              const Text(
                'DryClean Plus Driver',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading Driver Portal...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  var firebaseReady = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[DriverApp] Firebase init fallback: $e');
    firebaseReady = false;
  }
  runApp(ChangeNotifierProvider(create: (_) => AppState(firebaseReady: firebaseReady), child: const DriverApp()));
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DC Driver',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _restore;
  @override
  void initState() {
    super.initState();
    _restore = Future.wait([
      context.read<AppState>().restore().catchError((e) {
        debugPrint('[DriverApp] Restore session error: $e');
      }),
      Future.delayed(const Duration(milliseconds: 1400)), // let the splash breathe
    ]).timeout(const Duration(seconds: 4), onTimeout: () {
      debugPrint('[DriverApp] Restore timed out - proceeding to gate');
      return [null, null];
    }).catchError((_) => [null, null]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _restore,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SplashScreen();
          return Selector<AppState, bool>(
            selector: (_, s) => s.signedIn,
            builder: (_, signedIn, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: signedIn ? const HomeScreen() : const LoginScreen(),
            ),
          );
        },
      );
}
