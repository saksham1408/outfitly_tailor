import 'package:flutter/foundation.dart';

/// Partner-facing profile snapshot from the `tailor_profiles` table.
///
/// The table is owned by the tailor — one row per auth.users.id — and
/// carries the dispatch-critical fields the Partner app needs at
/// every surface:
///
///   * [fullName]         — shown on the customer's tracking screen
///   * [phone]            — dispatch contact, surfaced in account view
///   * [experienceYears]  — skill gating, shown on customer card
///
/// Both [createdAt] and [updatedAt] are server timestamps, kept
/// nullable so the model survives a row that hasn't been re-read
/// yet after a local mutation.
@immutable
class TailorProfile {
  const TailorProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.experienceYears,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final int experienceYears;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TailorProfile.fromJson(Map<String, dynamic> json) {
    // `experience_years` comes back as `int` today but coerce via
    // `num` so a future driver upgrade that returns it as a larger
    // numeric type doesn't crash a parse.
    return TailorProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      experienceYears:
          (json['experience_years'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  TailorProfile copyWith({
    String? fullName,
    String? phone,
    int? experienceYears,
  }) {
    return TailorProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      experienceYears: experienceYears ?? this.experienceYears,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
