import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/radar/domain/tailor_appointment.dart';
import '../../features/radar/presentation/active_job_screen.dart';
import '../../features/radar/presentation/radar_screen.dart';
import '../network/supabase_client.dart';

/// App-wide route configuration.
///
/// A deliberately tiny graph — Partners only ever see three surfaces:
///   * `/login`    — email + password entry (no self sign-up)
///   * `/radar`    — listening dashboard (the home screen)
///   * `/active-job` — after accepting a request
///
/// The `redirect` callback is the auth gate. It runs on every route
/// change and bounces signed-out users to `/login`, plus bounces
/// already-signed-in users away from `/login` back onto the radar.
/// That means the app never needs to check auth state inside a screen
/// — by the time a screen mounts, the session has been validated.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/radar',
    redirect: (context, state) {
      final loggedIn = AppSupabase.client.auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/radar';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/radar',
        name: 'radar',
        builder: (_, _) => const RadarScreen(),
      ),
      GoRoute(
        path: '/active-job',
        name: 'activeJob',
        builder: (context, state) {
          // The accepted appointment is handed through `extra` so we
          // avoid a second fetch immediately after the accept UPDATE
          // already returned the authoritative row.
          final appt = state.extra as TailorAppointment;
          return ActiveJobScreen(appointment: appt);
        },
      ),
    ],
  );
}
