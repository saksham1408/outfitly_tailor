import 'package:flutter/foundation.dart';

/// Lifecycle of a tailor dispatch request.
///
/// The string values are the canonical Supabase enum / text-column
/// values — both apps (customer + partner) agree on these strings,
/// so changing one here means migrating the database too.
///
/// Happy-path progression:
///
///   pending → accepted → enRoute → arrived → completed
///                                       ↘ cancelled
///
/// `enRoute` and `arrived` were added in migration 026 so the
/// customer's tracking screen can show a delivery-app-style
/// timeline as the tailor moves through their visit.
///
/// The Dart enum uses lower-camelCase, but the column stores the
/// snake_case form (`en_route`); [fromString] / [asDbString]
/// bridge the two so callers don't have to think about it.
enum AppointmentStatus {
  pending,
  accepted,
  enRoute,
  arrived,
  completed,
  cancelled;

  static AppointmentStatus fromString(String? raw) {
    switch (raw) {
      case 'accepted':
        return AppointmentStatus.accepted;
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
  /// column. Defaults to [name] for the single-word states; the
  /// multi-word `enRoute` is the lone special case.
  String get asDbString {
    switch (this) {
      case AppointmentStatus.enRoute:
        return 'en_route';
      default:
        return name;
    }
  }

  /// Position in the happy-path progression. Used by the active
  /// job screen's stepper to render the current node + decide
  /// which CTA to show next. `cancelled` returns -1 so callers
  /// can branch on it.
  int get progressIndex {
    switch (this) {
      case AppointmentStatus.pending:
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
  /// `cancelled`, or the not-yet-claimed `pending`). The Partner
  /// UI uses this to label the primary CTA.
  AppointmentStatus? get nextForward {
    switch (this) {
      case AppointmentStatus.accepted:
        return AppointmentStatus.enRoute;
      case AppointmentStatus.enRoute:
        return AppointmentStatus.arrived;
      case AppointmentStatus.arrived:
        return AppointmentStatus.completed;
      case AppointmentStatus.pending:
      case AppointmentStatus.completed:
      case AppointmentStatus.cancelled:
        return null;
    }
  }
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
