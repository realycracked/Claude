import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
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

  // 1) Charge la config (clés TMDB/Supabase, nom, couleur, code secret).
  await AppConfig.load();

  // 2) Initialise Supabase si configuré (sinon mode local pur).
  await SupabaseService.init();

  // 3) Stockage local + services + contrôleur.
  final local = await LocalStore.create();
  final parental = ParentalService();
  final repo = ContentRepository(local: local, parental: parental);
  final controller = AppController(local: local, repo: repo, parental: parental);
  await controller.bootstrap();

  // Interface immersive (idéale TV + téléphone plein écran).
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
      child: MaterialApp(
        title: AppConfig.instance.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const SplashScreen(),
      ),
    );
  }
}
