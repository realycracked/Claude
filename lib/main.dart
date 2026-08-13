import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'models/app_settings.dart';
import 'services/content_repository.dart';
import 'services/download_service.dart';
import 'services/local_store.dart';
import 'services/parental_service.dart';
import 'services/supabase_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Remplace l'affreux écran gris d'erreur par un message lisible (utile en release).
  ErrorWidget.builder = (details) => _FriendlyError(details: details);

  await AppConfig.load();
  await SupabaseService.init();

  final local = await LocalStore.create();
  final parental = ParentalService();
  final repo = ContentRepository(local: local, parental: parental);
  final controller = AppController(local: local, repo: repo, parental: parental);
  await controller.bootstrap();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(NovaApp(controller: controller, downloads: DownloadService()));
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key, required this.controller, required this.downloads});

  final AppController controller;
  final DownloadService downloads;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        Provider<DownloadService>.value(value: downloads),
        Provider<ParentalService>.value(value: controller.parental),
      ],
      // Le thème (couleur d'accent) suit les réglages, en direct.
      child: Consumer<AppController>(
        builder: (context, c, _) {
          final accent = Color(
            AppSettings.accentOptions[c.settings.accent] ??
                AppSettings.accentOptions['red']!,
          );
          return MaterialApp(
            title: AppConfig.instance.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(accentOverride: accent),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// Écran d'erreur sombre et discret (au lieu du carré gris par défaut).
class _FriendlyError extends StatelessWidget {
  const _FriendlyError({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0F),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Oups, un souci d\'affichage',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            details.exceptionAsString(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
