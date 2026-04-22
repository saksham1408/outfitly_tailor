import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Entry point for the Outfitly Tailor Partner App.
///
/// Two pieces of boot-time work happen before the first frame paints:
///   1. `.env` is loaded so we can read Supabase credentials — the
///      file is bundled as an asset via pubspec.yaml.
///   2. Supabase is initialized against the SAME project the customer
///      app uses. Both apps hit the same `tailor_appointments` table;
///      the Partner app writes `status` + `tailor_id`, the customer
///      app reads those fields for live order tracking.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const OutfitlyTailorApp());
}

/// Root application widget.
///
/// Uses [MaterialApp.router] so GoRouter owns navigation end-to-end
/// (including the auth-aware redirect that bounces signed-out users
/// to `/login` before the radar screen can mount).
class OutfitlyTailorApp extends StatelessWidget {
  const OutfitlyTailorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Outfitly Tailor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
