import 'package:firebase_core/firebase_core.dart';
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
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  var firebaseReady = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
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
      context.read<AppState>().restore(),
      Future.delayed(const Duration(milliseconds: 1400)), // let the splash breathe
    ]);
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
