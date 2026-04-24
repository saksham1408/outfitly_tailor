import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/push/device_token_service.dart';

/// Single seam between the Tailor app's UI and Supabase Auth + the
/// `tailor_profiles` table.
///
/// The UI layer never touches `AppSupabase.client.auth` directly — all
/// sign-in / sign-up / sign-out work goes through this service so we
/// have one place to (a) swap the backend for tests, (b) layer on
/// retries / analytics, and (c) keep the profile-INSERT side effect
/// atomic with the auth signup.
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;
  final DeviceTokenService _deviceTokens = DeviceTokenService();

  /// Sign an existing tailor in with email + password. On success the
  /// Supabase session is persisted automatically — the router's
  /// redirect gate picks it up and forwards to `/radar`.
  ///
  /// Throws [AuthException] on bad credentials / network failure.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    // Fire-and-forget — the stub no-ops until FCM is wired up, so
    // this is safe to call today. Once the integration lands, the
    // device token registers here and the tailor is reachable for
    // "new pending dispatch" pushes.
    unawaited(_deviceTokens.registerCurrent());
  }

  /// Create a new tailor Partner account.
  ///
  /// Two writes happen under the covers, in order:
  ///   1. `auth.signUp()` creates the auth user (and — on projects
  ///      with email confirmations OFF — immediately signs them in).
  ///   2. An INSERT into `public.tailor_profiles` stitches the
  ///      Partner-facing fields (name, phone, years) to the auth uid.
  ///
  /// If step 2 fails AFTER step 1 has created the auth user, we'd be
  /// left with an orphan account the user can't complete. Rather than
  /// carry that zombie state forward, we sign the partial user back
  /// out and surface the original error — the user can try again
  /// cleanly.
  ///
  /// [experience] is accepted as a String because the UI field is a
  /// free-text numeric input; we parse and validate before kicking
  /// off the network round-trip so client-side errors cost nothing.
  Future<void> registerTailor({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String experience,
  }) async {
    // ── Client-side validation ──
    final years = int.tryParse(experience.trim());
    if (years == null || years < 0 || years > 99) {
      throw const AuthException(
        'Years of experience must be a whole number between 0 and 99.',
      );
    }

    // ── Step 1: create the auth user ──
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      // Can happen if email confirmations are on AND the user already
      // exists without a confirmed address. Surface a friendly message
      // instead of letting the null crash a later line.
      throw const AuthException(
        'Could not create the account. Please check your email and try again.',
      );
    }

    // ── Step 2: persist the Partner-facing profile ──
    try {
      await _client.from('tailor_profiles').insert({
        'id': user.id,
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'experience_years': years,
      });
    } catch (e) {
      // Roll the session back — the auth user technically exists on
      // the server but the app-side profile is missing, so treating
      // this as "logged in" would soft-brick the next launch.
      await _client.auth.signOut();
      rethrow;
    }

    // First-login push-token register, same rationale as [login].
    unawaited(_deviceTokens.registerCurrent());
  }

  /// Explicit sign-out (used from the profile screen's logout button).
  /// The device-token delete has to run BEFORE signOut — once auth.uid()
  /// flips to null, the RLS policy on device_tokens would reject the
  /// DELETE.
  Future<void> logout() async {
    await _deviceTokens.unregisterCurrent();
    await _client.auth.signOut();
  }
}
