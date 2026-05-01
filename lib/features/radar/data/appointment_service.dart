import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_appointment.dart';

/// Distinct reasons a [AppointmentService.progressJob] call can fail.
///
/// We surface these as a typed exception ([ProgressJobException]) instead
/// of swallowing every miss as a silent `null`. The Active Job screen used
/// to bounce the tailor back to the radar with a generic "no longer
/// active" message regardless of the actual cause — that hid three very
/// different bugs behind one copy line:
///
///   * `cancelled` — the customer pulled the request mid-visit, fair
///     enough; the radar message is appropriate.
///   * `notAssigned` — the row's `tailor_id` doesn't match the signed-in
///     user. Symptom of a session swap or a race we lost on accept.
///   * `staleStatus` — the row's status doesn't match what the UI
///     thought it was. Usually a stale screen after a hot reload.
///   * `notFound` — RLS hid the row from us (or it was hard-deleted).
///
/// The screen reads [ProgressJobException.reason] to pick copy that
/// actually helps the tailor diagnose what happened.
enum ProgressJobFailure {
  cancelled,
  notAssigned,
  staleStatus,
  notFound,
}

/// Thrown by [AppointmentService.progressJob] when the UPDATE matched
/// zero rows. The [reason] field tells the UI which of the four
/// failure modes fired so it can render specific copy + decide
/// whether to bounce back to the radar.
class ProgressJobException implements Exception {
  ProgressJobException(this.reason, this.message);
  final ProgressJobFailure reason;
  final String message;

  @override
  String toString() => message;
}

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

  /// Realtime feed of dispatch requests awaiting accept.
  ///
  /// Two row types surface here, in one merged feed:
  ///   * `status='pending'` (legacy broadcast) — visible to every
  ///     online tailor via the original RLS policy.
  ///   * `status='pending_tailor_approval'` (marketplace direct) —
  ///     visible ONLY to the hand-picked tailor via the RLS scope
  ///     added in migration 036.
  ///
  /// We deliberately *don't* server-side filter on `status` because
  /// supabase-flutter's `.stream()` only supports `.eq()` filters
  /// (no `.in_()` / `.or()`). Filtering after the wire keeps the
  /// stream subscription single-channel, and RLS already trims the
  /// row set down to "rows this tailor is allowed to see" — that's
  /// the broadcast pending set + the rows specifically directed at
  /// this tailor (regardless of status). The client-side `where`
  /// then drops anything that's not awaiting-accept (the tailor's
  /// own accepted / en_route / arrived / completed jobs belong to
  /// the active job screen, not the radar).
  ///
  /// Supabase's `.stream()` emits the **full** filtered set on
  /// every mutation (not just a delta). The radar screen dedupes
  /// by id so the "new request" sheet only pops once per
  /// appointment — see the `_promptedIds` guard in RadarScreen.
  Stream<List<TailorAppointment>> pendingRequests() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('scheduled_time', ascending: true)
        .map(
          (rows) => rows
              .map((row) => TailorAppointment.fromJson(row))
              .where((a) => a.status.isAwaitingAccept)
              .toList(growable: false),
        );
  }

  /// Read a single appointment by id. Returns null if RLS hides it
  /// (i.e. the row isn't pending and isn't claimed by the caller) or
  /// if the row was hard-deleted.
  ///
  /// Used by the active job screen's `staleStatus` recovery path so
  /// the screen can re-sync to the DB's truth instead of bouncing the
  /// tailor back to the radar over a recoverable hiccup.
  Future<TailorAppointment?> fetchById(String appointmentId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', appointmentId)
        .maybeSingle();
    if (row == null) return null;
    return TailorAppointment.fromJson(row);
  }

  /// Claim an awaiting-accept appointment for the current tailor.
  ///
  /// We branch by the row's CURRENT status (read first), then run
  /// the matching UPDATE. Splitting the read and write makes the
  /// failure mode explicit — if the row has vanished or moved past
  /// pending, we know exactly which case to surface — and avoids
  /// a subtle bug where `.update().eq().select().maybeSingle()`
  /// can throw under some supabase-flutter versions when the
  /// UPDATE matches zero rows.
  ///
  /// Two paths:
  ///   * **Broadcast (`pending`)** — race-guarded UPDATE that
  ///     flips status AND fills tailor_id. A late tap loses the
  ///     race cleanly because the WHERE doesn't match.
  ///   * **Direct (`pending_tailor_approval`)** — UPDATE just
  ///     flips status. RLS already scoped the row to this tailor,
  ///     and we re-assert tailor_id in the WHERE for belt-and-
  ///     braces.
  ///
  /// Returns the updated [TailorAppointment] on success, null if
  /// the row no longer exists / is already claimed / was cancelled.
  /// Throws only on auth/network errors; the UI distinguishes "lost
  /// the race" (null) from "something blew up" (exception).
  Future<TailorAppointment?> acceptRequest(String appointmentId) async {
    final tailor = _client.auth.currentUser;
    if (tailor == null) {
      throw StateError('Cannot accept a request while signed out.');
    }

    // Phase 1: read current state. RLS already scopes which rows
    // we can see — if the SELECT returns null, the row is either
    // hard-deleted or hidden from us, and acceptance is impossible.
    final current = await _client
        .from(_table)
        .select('id, status, tailor_id')
        .eq('id', appointmentId)
        .maybeSingle();

    if (current == null) {
      debugPrint('acceptRequest: row $appointmentId not visible / not found');
      return null;
    }

    final currentStatus =
        AppointmentStatus.fromString(current['status'] as String?);
    final currentTailorId = current['tailor_id'] as String?;

    if (currentStatus == AppointmentStatus.pending &&
        currentTailorId == null) {
      // Broadcast claim — race-guarded.
      final rows = await _client
          .from(_table)
          .update({
            'status': AppointmentStatus.accepted.asDbString,
            'tailor_id': tailor.id,
          })
          .eq('id', appointmentId)
          .eq('status', AppointmentStatus.pending.asDbString)
          .select();
      if (rows.isEmpty) return null;
      return TailorAppointment.fromJson(rows.first);
    }

    if (currentStatus == AppointmentStatus.pendingTailorApproval &&
        currentTailorId == tailor.id) {
      // Direct accept — flip status only; tailor_id is already us.
      final rows = await _client
          .from(_table)
          .update({'status': AppointmentStatus.accepted.asDbString})
          .eq('id', appointmentId)
          .eq('status',
              AppointmentStatus.pendingTailorApproval.asDbString)
          .eq('tailor_id', tailor.id)
          .select();
      if (rows.isEmpty) return null;
      return TailorAppointment.fromJson(rows.first);
    }

    // Anything else — accepted by another tailor, cancelled,
    // assigned to someone else, etc. — we can't do anything with.
    debugPrint(
      'acceptRequest: cannot accept appt=$appointmentId. '
      'status=$currentStatus, tailor_id=$currentTailorId, '
      'me=${tailor.id}',
    );
    return null;
  }

  /// Advance the appointment to the next lifecycle stage.
  ///
  /// Used by the active job screen's stepper: accepted → enRoute,
  /// enRoute → arrived, arrived → completed. The UPDATE is guarded
  /// by `tailor_id = auth.uid()` (server-side via RLS) and by
  /// `status = expectedFrom` (client-side here) so a stale tap on
  /// an outdated screen can't skip a step.
  ///
  /// On success returns the updated [TailorAppointment]. On failure
  /// throws [ProgressJobException] with a [ProgressJobFailure] code
  /// so the UI can show a specific reason (instead of the old
  /// "no longer active" catch-all). The four failure modes are
  /// determined by a follow-up SELECT — we only do that read when
  /// the UPDATE matched zero rows, so the happy path costs one
  /// round-trip exactly as before.
  Future<TailorAppointment> progressJob({
    required String appointmentId,
    required AppointmentStatus expectedFrom,
    required AppointmentStatus to,
  }) async {
    final tailor = _client.auth.currentUser;
    if (tailor == null) {
      throw ProgressJobException(
        ProgressJobFailure.notAssigned,
        'You are signed out. Sign back in to continue this job.',
      );
    }

    final updated = await _client
        .from(_table)
        .update({'status': to.asDbString})
        .eq('id', appointmentId)
        .eq('tailor_id', tailor.id)
        .eq('status', expectedFrom.asDbString)
        .select()
        .maybeSingle();

    if (updated != null) {
      return TailorAppointment.fromJson(updated);
    }

    // UPDATE matched zero rows. Read the row back to figure out which
    // of the four failure modes we hit so we can surface a useful
    // message. `maybeSingle` so a hard-deleted/RLS-hidden row returns
    // null rather than throwing.
    final current = await _client
        .from(_table)
        .select()
        .eq('id', appointmentId)
        .maybeSingle();

    if (current == null) {
      debugPrint(
        'progressJob: row $appointmentId not visible to tailor ${tailor.id} '
        '(hard-deleted or RLS-hidden).',
      );
      throw ProgressJobException(
        ProgressJobFailure.notFound,
        'This job is no longer available. Returning to the radar.',
      );
    }

    final actualTailorId = current['tailor_id']?.toString();
    final actualStatus = AppointmentStatus.fromString(
      current['status']?.toString(),
    );

    debugPrint(
      'progressJob: UPDATE matched 0 rows. expected status=$expectedFrom, '
      'actual status=$actualStatus. expected tailor_id=${tailor.id}, '
      'actual tailor_id=$actualTailorId.',
    );

    if (actualStatus == AppointmentStatus.cancelled) {
      throw ProgressJobException(
        ProgressJobFailure.cancelled,
        'The customer cancelled this visit. Returning to the radar.',
      );
    }

    if (actualTailorId != tailor.id) {
      throw ProgressJobException(
        ProgressJobFailure.notAssigned,
        actualTailorId == null
            ? 'This job was un-claimed (admin reset). Re-accept it from '
                'the radar.'
            : 'This job is now assigned to a different tailor. Returning '
                'to the radar.',
      );
    }

    if (actualStatus != expectedFrom) {
      throw ProgressJobException(
        ProgressJobFailure.staleStatus,
        'Job is already at "${actualStatus.asDbString}" — your screen was '
            'out of sync. Pull to refresh.',
      );
    }

    // Should be unreachable: the row exists, is ours, and is at the
    // expected status, yet UPDATE matched nothing. Treat as a generic
    // RLS rejection.
    throw ProgressJobException(
      ProgressJobFailure.notFound,
      'Could not update status. Please try again.',
    );
  }
}
