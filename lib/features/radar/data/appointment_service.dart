import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_appointment.dart';

/// Data layer around the `tailor_appointments` Supabase table.
///
/// Two methods cover the radar's whole lifecycle:
///   * [pendingRequests] streams every pending row in real time so the
///     radar screen redraws the instant a customer requests a visit.
///   * [acceptRequest] claims a row for the currently-signed-in tailor
///     with a conditional UPDATE that guards against the two-tailors-
///     tap-at-the-same-instant race.
class AppointmentService {
  AppointmentService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'tailor_appointments';

  /// Realtime feed of pending dispatch requests.
  ///
  /// Note that Supabase's `.stream()` emits the **full** filtered set on
  /// every mutation (not just a delta). The radar screen dedupes by id
  /// so the "new request" sheet only pops once per appointment — see
  /// the `_promptedIds` guard in RadarScreen.
  Stream<List<TailorAppointment>> pendingRequests() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('status', AppointmentStatus.pending.asDbString)
        .order('scheduled_time', ascending: true)
        .map(
          (rows) => rows
              .map((row) => TailorAppointment.fromJson(row))
              .toList(growable: false),
        );
  }

  /// Claim a pending appointment for the current tailor.
  ///
  /// Returns the updated [TailorAppointment] on success, or `null` if
  /// the row is no longer pending (i.e. another tailor got there
  /// first). The `.eq('status', 'pending')` clause on the UPDATE is
  /// the race guard — without it, a late accept could overwrite a
  /// row another tailor has already claimed.
  Future<TailorAppointment?> acceptRequest(String appointmentId) async {
    final tailor = _client.auth.currentUser;
    if (tailor == null) {
      throw StateError('Cannot accept a request while signed out.');
    }

    final updated = await _client
        .from(_table)
        .update({
          'status': AppointmentStatus.accepted.asDbString,
          'tailor_id': tailor.id,
        })
        .eq('id', appointmentId)
        .eq('status', AppointmentStatus.pending.asDbString)
        .select()
        .maybeSingle();

    if (updated == null) return null;
    return TailorAppointment.fromJson(updated);
  }

  /// Advance the appointment to the next lifecycle stage.
  ///
  /// Used by the active job screen's stepper: accepted → enRoute,
  /// enRoute → arrived, arrived → completed. The UPDATE is guarded
  /// by `tailor_id = auth.uid()` (server-side via RLS) and by
  /// `status = expectedFrom` (client-side here) so a stale tap on
  /// an outdated screen can't skip a step.
  ///
  /// Returns the updated row on success, or null if the guards
  /// failed (e.g. the customer cancelled in the meantime).
  Future<TailorAppointment?> progressJob({
    required String appointmentId,
    required AppointmentStatus expectedFrom,
    required AppointmentStatus to,
  }) async {
    final tailor = _client.auth.currentUser;
    if (tailor == null) {
      throw StateError('Cannot progress a job while signed out.');
    }

    final updated = await _client
        .from(_table)
        .update({'status': to.asDbString})
        .eq('id', appointmentId)
        .eq('tailor_id', tailor.id)
        .eq('status', expectedFrom.asDbString)
        .select()
        .maybeSingle();

    if (updated == null) return null;
    return TailorAppointment.fromJson(updated);
  }
}
