import 'package:flutter/foundation.dart';

/// Lifecycle of a tailor dispatch request.
///
/// The string values are the canonical Supabase enum / text-column
/// values — both apps (customer + partner) agree on these strings,
/// so changing one here means migrating the database too.
enum AppointmentStatus {
  pending,
  accepted,
  completed,
  cancelled;

  static AppointmentStatus fromString(String? raw) {
    switch (raw) {
      case 'accepted':
        return AppointmentStatus.accepted;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'pending':
      default:
        return AppointmentStatus.pending;
    }
  }

  String get asDbString => name;
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
