import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin accessor around the app-wide Supabase singleton.
///
/// Mirrors the pattern used by the customer app so anyone jumping
/// between the two codebases reaches for the same shape. Wrapping the
/// singleton gives us a single seam to swap (e.g. for tests) without
/// ripping call sites throughout features.
abstract final class AppSupabase {
  /// The active [SupabaseClient]. Safe to call after `main()` has
  /// finished initializing Supabase — which it always has, because
  /// nothing in the widget tree can render before that completes.
  static SupabaseClient get client => Supabase.instance.client;
}
