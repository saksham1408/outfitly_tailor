import 'package:flutter/foundation.dart';

/// Lifecycle of a tailor dispatch request.
///
/// The string values are the canonical Supabase enum / text-column
/// values — both apps (customer + partner) agree on these strings,
/// so changing one here means migrating the database too.
///
/// Two booking modes share this enum:
///
///   * **Broadcast (legacy)** — the customer's request fans out to
///     every tailor on the radar; first to accept wins:
///     pending → accepted → enRoute → arrived → completed
///   * **Direct request (marketplace)** — the customer hand-picked
///     a specific tailor from the selection screen, so the row
///     already carries `tailor_id` and lands in:
///     pendingTailorApproval → accepted → enRoute → arrived → completed
///
/// Either branch can short-circuit to `cancelled`. Both pending
/// variants are surfaced together on the radar; the UI labels
/// direct requests so the tailor knows they were specifically
/// chosen.
///
/// Migration 036 added `pendingTailorApproval` plus the RLS scope
/// that hides direct-request rows from every tailor except the
/// chosen one — so the Partner App stream can drop its server-side
/// status filter and let RLS do the heavy lifting.
enum AppointmentStatus {
  pending,
  pendingTailorApproval,
  accepted,
  enRoute,
  arrived,
  completed,
  cancelled;

  static AppointmentStatus fromString(String? raw) {
    switch (raw) {
      case 'accepted':
        return AppointmentStatus.accepted;
      case 'pending_tailor_approval':
        return AppointmentStatus.pendingTailorApproval;
      case 'en_route':
        return AppointmentStatus.enRoute;
      case 'arrived':
        return AppointmentStatus.arrived;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'pending':
      default:
        return AppointmentStatus.pending;
    }
  }

  /// Snake-case form stored in the `tailor_appointments.status`
  /// column. Most enum values match `name` directly; the multi-
  /// word ones get explicit casing.
  String get asDbString {
    switch (this) {
      case AppointmentStatus.enRoute:
        return 'en_route';
      case AppointmentStatus.pendingTailorApproval:
        return 'pending_tailor_approval';
      default:
        return name;
    }
  }

  /// Position in the happy-path progression. Both pending variants
  /// share index 0 because they're functionally the same step from
  /// the Partner UI's view: a pre-accept request awaiting a tap.
  /// `cancelled` returns -1 so callers can branch on it.
  int get progressIndex {
    switch (this) {
      case AppointmentStatus.pending:
      case AppointmentStatus.pendingTailorApproval:
        return 0;
      case AppointmentStatus.accepted:
        return 1;
      case AppointmentStatus.enRoute:
        return 2;
      case AppointmentStatus.arrived:
        return 3;
      case AppointmentStatus.completed:
        return 4;
      case AppointmentStatus.cancelled:
        return -1;
    }
  }

  /// The next state the tailor can advance to from this one, or
  /// null if there's no further forward step (`completed`,
  /// `cancelled`, or the not-yet-claimed pending variants — those
  /// transition via [acceptRequest], not the stepper).
  AppointmentStatus? get nextForward {
    switch (this) {
      case AppointmentStatus.accepted:
        return AppointmentStatus.enRoute;
      case AppointmentStatus.enRoute:
        return AppointmentStatus.arrived;
      case AppointmentStatus.arrived:
        return AppointmentStatus.completed;
      case AppointmentStatus.pending:
      case AppointmentStatus.pendingTailorApproval:
      case AppointmentStatus.completed:
      case AppointmentStatus.cancelled:
        return null;
    }
  }

  /// Whether this row is a pre-accept request the radar should
  /// surface (either bucket — broadcast or direct).
  bool get isAwaitingAccept =>
      this == AppointmentStatus.pending ||
      this == AppointmentStatus.pendingTailorApproval;
}

/// Wire-format representation of one tailor visit request.
///
/// Fields mirror the `tailor_appointments` Supabase table:
///   * `id`               — row PK, UUID
///   * `user_id`          — the customer who requested the visit
///   * `tailor_id`        — null while pending, set on accept
///   * `address`          — plaintext pickup address
///   * `scheduled_time`   — when the customer wants the visit
///   * `status`           — see [AppointmentStatus]
///   * `created_at`       — server timestamp (display-only)
///
/// [fromJson] is deliberately tolerant: missing fields get safe
/// defaults so an in-progress schema migration on the backend can't
/// crash the app mid-shift.
@immutable
class TailorAppointment {
  const TailorAppointment({
    required this.id,
    required this.userId,
    required this.tailorId,
    required this.address,
    required this.scheduledTime,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? tailorId;
  final String address;
  final DateTime scheduledTime;
  final AppointmentStatus status;
  final DateTime? createdAt;

  factory TailorAppointment.fromJson(Map<String, dynamic> json) {
    return TailorAppointment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      tailorId: json['tailor_id']?.toString(),
      address: json['address']?.toString() ?? '',
      scheduledTime:
          DateTime.tryParse(json['scheduled_time']?.toString() ?? '') ??
              DateTime.now(),
      status: AppointmentStatus.fromString(json['status']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  TailorAppointment copyWith({
    String? tailorId,
    AppointmentStatus? status,
  }) {
    return TailorAppointment(
      id: id,
      userId: userId,
      tailorId: tailorId ?? this.tailorId,
      address: address,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
