import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../state/app_controller.dart';
import 'home_shell.dart';
import 'profiles_screen.dart';

/// Écran de démarrage : logo animé, puis redirige vers profils ou accueil.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final c = context.read<AppController>();
    if (c.activeProfile == null) {
      _go(const ProfilesScreen());
    } else {
      c.reloadCatalog();
      _go(const HomeShell());
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: screen),
      ),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.instance;
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _ac, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: _ac,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cfg.appName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: cfg.accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cfg.tagline,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
