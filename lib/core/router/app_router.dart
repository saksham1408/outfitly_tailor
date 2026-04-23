import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/radar/domain/tailor_appointment.dart';
import '../../features/radar/presentation/active_job_screen.dart';
import '../../features/radar/presentation/radar_screen.dart';
import '../network/supabase_client.dart';

/// App-wide route configuration.
///
/// A deliberately tiny graph — Partners see four surfaces:
///   * `/login`     — returning-partner sign-in
///   * `/register`  — self-serve partner application form
///   * `/radar`     — listening dashboard (the home screen)
///   * `/active-job` — after accepting a request
///
/// The `redirect` callback is the auth gate. It runs on every route
/// change (including cold launch) and handles session persistence for
/// us:
///
///   * Cold launch with a persisted Supabase session → we start at
///     `/radar` (the [initialLocation]) and the redirect lets us
///     through unchanged.
///   * Cold launch with NO session → the redirect intercepts and
///     punts us to `/login`.
///   * Signing in (or registering) creates a session; the redirect
///     bounces `/login` and `/register` back to `/radar` so the
///     authenticated user never sees the auth screens again until
///     they log out.
///
/// Supabase's Flutter SDK rehydrates the session from disk before
/// `runApp()` completes (we `await Supabase.initialize(...)` in
/// main), so `currentSession` is authoritative on the very first
/// redirect call.
abstract final class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Public auth surfaces — reachable without a session.
  static const _publicPaths = <String>{'/login', '/register'};

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/radar',
    redirect: (context, state) {
      final loggedIn = AppSupabase.client.auth.currentSession != null;
      final path = state.matchedLocation;
      final onPublic = _publicPaths.contains(path);

      if (!loggedIn && !onPublic) return '/login';
      if (loggedIn && onPublic) return '/radar';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, _) => const RegisterScreen(),
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
