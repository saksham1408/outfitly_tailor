import 'dart:math';

import '../domain/earnings_record.dart';

/// Read seam for the tailor's earnings ledger.
///
/// Currently mocked — the customer-side payments flow hasn't shipped
/// yet, so the `tailor_earnings` Supabase table doesn't exist in
/// production. The mock generator is deterministic per-call so the
/// dashboard reads consistently across hot reloads while developing.
///
/// When the real table lands, swap the bodies of [fetchSummary] and
/// [fetchRecent] with `_client.from('tailor_earnings')…` queries —
/// the public surface of this class is shaped to match.
class EarningsService {
  EarningsService();

  /// One screen-worth of recent transactions, newest first.
  Future<List<EarningsRecord>> fetchRecent({int limit = 12}) async {
    // Tiny artificial delay so the loading shimmer in the dashboard
    // gets a chance to render — makes the eventual real-network
    // version feel familiar.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _mockLedger().take(limit).toList(growable: false);
  }

  /// Aggregates over the same mocked ledger so the summary card and
  /// the transaction list never disagree.
  Future<EarningsSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final ledger = _mockLedger();
    final now = DateTime.now();
    // Monday 00:00 of the current ISO week.
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final totalBalance =
        ledger.fold<double>(0, (sum, e) => sum + e.amount);
    final thisWeek = ledger
        .where((e) => !e.date.isBefore(weekStart))
        .fold<double>(0, (sum, e) => sum + e.amount);

    return EarningsSummary(
      totalBalance: totalBalance,
      thisWeek: thisWeek,
      completedJobs: ledger.length,
    );
  }

  /// 10 deterministic mock rows seeded off a fixed RNG so reloads
  /// don't reshuffle the dashboard mid-demo.
  List<EarningsRecord> _mockLedger() {
    final rng = Random(42);
    final now = DateTime.now();
    const jobLabels = [
      'Sherwani — Sangeet',
      'Bridal Lehenga Fitting',
      'Office Suit — 2pc',
      'Anarkali Hemming',
      'Blouse — Custom',
      'Kurta Pajama',
      'Wedding Sherwani',
      'Saree Fall & Pico',
      'Trouser Alteration',
      'Designer Blouse',
    ];

    return List<EarningsRecord>.generate(jobLabels.length, (i) {
      final daysAgo = i + rng.nextInt(2); // 0..1 day jitter
      // Amounts roughly in ₹400–₹4,200 range, stepped to nice numbers.
      final amount = 400 + (rng.nextInt(38) * 100).toDouble();
      // Most recent two are still pending payout, the rest are paid.
      final status = i < 2 ? EarningsStatus.pending : EarningsStatus.paid;

      return EarningsRecord(
        id: 'mock-${i.toString().padLeft(3, '0')}',
        jobId: jobLabels[i],
        amount: amount,
        date: now.subtract(Duration(days: daysAgo, hours: rng.nextInt(20))),
        status: status,
      );
    });
  }
}

/// Aggregates that drive the top summary card on the earnings
/// dashboard. Kept as a tiny value object so widgets can take it as
/// a single argument instead of three loose doubles.
class EarningsSummary {
  const EarningsSummary({
    required this.totalBalance,
    required this.thisWeek,
    required this.completedJobs,
  });

  final double totalBalance;
  final double thisWeek;
  final int completedJobs;
}
