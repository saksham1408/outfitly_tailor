import 'package:flutter/foundation.dart';

/// Payout state of a single earnings entry.
///
///   * [pending] — job completed, payout queued for the next cycle
///   * [paid]    — money has landed in the tailor's bank account
///
/// The string values are the canonical Supabase enum / text-column
/// values; both apps agree on these strings.
enum EarningsStatus {
  pending,
  paid;

  static EarningsStatus fromString(String? raw) {
    switch (raw) {
      case 'paid':
        return EarningsStatus.paid;
      case 'pending':
      default:
        return EarningsStatus.pending;
    }
  }

  String get asDbString => name;
}

/// One row in the tailor's earnings ledger.
///
/// Mirrors the `tailor_earnings` table:
///   * [id]      — row PK
///   * [jobId]   — FK to `tailor_appointments.id` (the visit that
///                 generated this earnings line)
///   * [amount]  — gross payout in ₹ for this job
///   * [date]    — when the job completed (NOT the payout date)
///   * [status]  — see [EarningsStatus]
///
/// Mocked in [EarningsService] for now — the table will be wired up
/// once the customer-side payments flow ships.
@immutable
class EarningsRecord {
  const EarningsRecord({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.date,
    required this.status,
  });

  final String id;
  final String jobId;
  final double amount;
  final DateTime date;
  final EarningsStatus status;

  factory EarningsRecord.fromJson(Map<String, dynamic> json) {
    return EarningsRecord(
      id: json['id']?.toString() ?? '',
      jobId: json['job_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      status: EarningsStatus.fromString(json['status']?.toString()),
    );
  }
}
