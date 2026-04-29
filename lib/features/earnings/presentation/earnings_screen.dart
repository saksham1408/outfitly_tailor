import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/earnings_service.dart';
import '../domain/earnings_record.dart';

/// Earnings tab on the bottom nav.
///
/// Layout, top to bottom:
///   1. A premium dark "balance" card showing Total Balance, This
///      Week's Earnings, and Completed Jobs.
///   2. A "Recent Transactions" list — each row a job, with a green
///      positive amount on the right and a relative date stamp.
///
/// All data is sourced from [EarningsService] which is currently
/// mocked. Pull-to-refresh re-fetches both the summary and the list
/// in parallel.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final EarningsService _service = EarningsService();

  EarningsSummary? _summary;
  List<EarningsRecord>? _recent;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchSummary(),
        _service.fetchRecent(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as EarningsSummary;
        _recent = results[1] as List<EarningsRecord>;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline,
              size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Could not load earnings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _load, child: const Text('RETRY')),
        ],
      );
    }

    final summary = _summary;
    final recent = _recent;
    if (summary == null || recent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: 28),
        _SectionLabel(text: 'RECENT TRANSACTIONS'),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _EmptyTransactions()
        else
          _TransactionsCard(records: recent),
      ],
    );
  }
}

/// Premium dark balance card. Big "Total Balance" number anchors
/// the eye, with This Week + Completed Jobs as supporting stats
/// on a divided row below.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF14141C),
            Color(0xFF0A0A10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.04),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TOTAL BALANCE',
                style: text.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(summary.totalBalance),
            style: text.displaySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: "THIS WEEK",
                  value: _formatCurrency(summary.thisWeek),
                  highlight: true,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: AppColors.divider,
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'COMPLETED JOBS',
                  value: summary.completedJobs.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: highlight ? AppColors.accent : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.records});

  final List<EarningsRecord> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < records.length; i++) ...[
            _TransactionRow(record: records[i]),
            if (i < records.length - 1)
              Container(
                height: 1,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.record});

  final EarningsRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pending = record.status == EarningsStatus.pending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: AppColors.accent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.jobId,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatRelative(record.date),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PENDING',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${_formatCurrency(record.amount)}',
            style: text.titleSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            'No transactions yet',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completed jobs will appear here.',
            style: text.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "₹1,250" — Indian-comma currency, no decimals (whole rupees).
String _formatCurrency(double amount) {
  final whole = amount.round();
  // Indian numbering: last 3 digits, then groups of 2.
  final s = whole.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    final fromRight = rest.length - i;
    buf.write(rest[i]);
    if (fromRight > 1 && fromRight.isOdd) buf.write(',');
  }
  return '₹$buf,$last3';
}

/// "Today", "Yesterday", "3 days ago", or fallback to "DD MMM".
String _formatRelative(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  final diff = today.difference(that).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
