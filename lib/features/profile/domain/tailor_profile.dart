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
///   * [rating]           — running average from customer reviews
///   * [totalReviews]     — denominator behind [rating]
///   * [specialties]      — garment categories the tailor advertises
///   * [isVerified]       — Outfitly Verified Master badge eligibility
///   * [totalEarnings]    — lifetime payout total (₹), display-only
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
    this.rating = 0.0,
    this.totalReviews = 0,
    this.specialties = const <String>[],
    this.isVerified = false,
    this.totalEarnings = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final int experienceYears;

  /// Running customer-rating average, 0.0–5.0. Defaulted to 0 for
  /// brand-new tailors with no reviews yet.
  final double rating;

  /// Number of customer reviews behind [rating]. Shown next to the
  /// stars as a credibility cue.
  final int totalReviews;

  /// Garment categories the tailor advertises (e.g. ['Sherwanis',
  /// 'Suits', 'Blouses']). Stored as a Postgres `text[]` column.
  final List<String> specialties;

  /// Outfitly Verified Master badge — set true after our internal
  /// quality review. Drives the gold/blue checkmark in the profile
  /// header and on the customer-side tracking screen.
  final bool isVerified;

  /// Lifetime gross earnings in ₹. Display-only on this surface;
  /// authoritative ledger lives in the `tailor_earnings` table.
  final double totalEarnings;

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
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      // The column is `text[]` in Postgres; the driver returns it as
      // a `List<dynamic>`. Coerce defensively so a string-typed
      // fallback (e.g. JSON-encoded array) doesn't throw.
      specialties: _parseSpecialties(json['specialties']),
      isVerified: json['is_verified'] == true,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static List<String> _parseSpecialties(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const <String>[];
  }

  TailorProfile copyWith({
    String? fullName,
    String? phone,
    int? experienceYears,
    double? rating,
    int? totalReviews,
    List<String>? specialties,
    bool? isVerified,
    double? totalEarnings,
  }) {
    return TailorProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      experienceYears: experienceYears ?? this.experienceYears,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      specialties: specialties ?? this.specialties,
      isVerified: isVerified ?? this.isVerified,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
