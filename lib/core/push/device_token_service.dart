import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';

/// Persists the current device's push-notification token in
/// `public.device_tokens` so the server can fan out pushes to every
/// device the signed-in tailor has the Partner app installed on.
///
/// The customer and Partner apps share the same Supabase project and
/// therefore the same `device_tokens` table. The [_appTag] constant
/// is the only field that differs between the two copies of this
/// service — it discriminates which app a given token belongs to so
/// the server-side notifier can address the right audience (e.g.
/// "new pending dispatch → push to every tailor token" vs. "my
/// appointment flipped to en_route → push to the customer's tokens").
///
/// This service intentionally does NOT depend on `firebase_messaging`
/// yet — the FCM / APNs integration is a follow-up that adds the
/// native platform plumbing. When that lands, the only change here is
/// to replace [_fetchPlatformToken] with a call into
/// `FirebaseMessaging.instance.getToken()` (plus the APNs permission
/// prompt on iOS). Every other seam is already in place.
class DeviceTokenService {
  DeviceTokenService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'device_tokens';
  static const String _appTag = 'tailor';

  /// Fetch the current push token and UPSERT it into `device_tokens`.
  /// Safe to call multiple times — the UNIQUE constraint on `token`
  /// means we either insert a fresh row or bump `updated_at` on the
  /// existing one.
  Future<void> registerCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[push] skipping token register — not signed in');
      return;
    }

    final platform = _currentPlatform();
    if (platform == null) {
      debugPrint('[push] unsupported platform — skipping register');
      return;
    }

    final token = await _fetchPlatformToken(platform);
    if (token == null) {
      debugPrint('[push] no token available — scaffold stub');
      return;
    }

    try {
      await _client.from(_table).upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'app': _appTag,
        },
        onConflict: 'token',
      );
      debugPrint('[push] device token registered ($platform, $_appTag)');
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  /// Delete the current device's token. Called on explicit sign-out
  /// so a previously-signed-in tailor doesn't keep getting pushes for
  /// the new tailor's account on this device.
  Future<void> unregisterCurrent() async {
    final platform = _currentPlatform();
    if (platform == null) return;

    final token = await _fetchPlatformToken(platform);
    if (token == null) return;

    try {
      await _client.from(_table).delete().eq('token', token);
      debugPrint('[push] device token unregistered');
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
  }

  String? _currentPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {
      // Platform.isX throws on unsupported targets. Fall through.
    }
    return null;
  }

  /// Scaffold stub — replaced by the real FCM / APNs fetch once
  /// the native platform config lands (GoogleService-Info.plist /
  /// google-services.json + firebase_messaging dependency). Returns
  /// null today so callers no-op cleanly.
  Future<String?> _fetchPlatformToken(String platform) async {
    // TODO(push): replace with:
    //   await FirebaseMessaging.instance.requestPermission();
    //   return FirebaseMessaging.instance.getToken();
    return null;
  }
}
