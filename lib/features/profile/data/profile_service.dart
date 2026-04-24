import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_profile.dart';

/// Read/write seam for the `tailor_profiles` table.
///
/// All reads and writes are scoped to `auth.uid()` — the RLS policies
/// on the table already enforce this server-side, but we key every
/// query on the client's uid too so a misconfigured environment surfaces
/// a missing-profile error instead of silently wandering into someone
/// else's row.
class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'tailor_profiles';

  /// Fetch the signed-in tailor's profile, or `null` if the row is
  /// missing (which should never happen in prod — registration always
  /// inserts one — but is worth handling gracefully rather than
  /// crashing the app on a manually-deleted row).
  Future<TailorProfile?> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot fetch profile while signed out.');
    }

    final row = await _client
        .from(_table)
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (row == null) return null;
    return TailorProfile.fromJson(row);
  }

  /// Update the fields the tailor is allowed to edit themselves.
  /// `experience_years` is validated on the client (0–99) to match
  /// the CHECK constraint on the column so we surface a clean error
  /// before the round-trip rather than leaning on Postgres's
  /// "check_violation" message.
  Future<TailorProfile> updateMine({
    required String fullName,
    required String phone,
    required int experienceYears,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot update profile while signed out.');
    }
    if (fullName.trim().isEmpty) {
      throw ArgumentError('Full name cannot be empty.');
    }
    if (phone.trim().isEmpty) {
      throw ArgumentError('Phone cannot be empty.');
    }
    if (experienceYears < 0 || experienceYears > 99) {
      throw ArgumentError(
        'Years of experience must be a whole number between 0 and 99.',
      );
    }

    final updated = await _client
        .from(_table)
        .update({
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'experience_years': experienceYears,
        })
        .eq('id', uid)
        .select()
        .single();

    return TailorProfile.fromJson(updated);
  }
}
