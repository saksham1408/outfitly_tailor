import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/tailor_appointment.dart';

/// Rendered immediately after a successful accept. Shows the job the
/// tailor just claimed — customer details, address, scheduled time
/// and the primary "open navigation" CTA.
///
/// `url_launcher` for handing off the address to Google/Apple Maps
/// is deliberately deferred to a later drop; today the button copies
/// the address to the clipboard so the tailor can paste it wherever
/// they prefer. That keeps this first cut dependency-light.
class ActiveJobScreen extends StatelessWidget {
  const ActiveJobScreen({super.key, required this.appointment});

  final TailorAppointment appointment;

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: appointment.address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shortUserId = appointment.userId.isEmpty
        ? '—'
        : appointment.userId.substring(
            0,
            appointment.userId.length < 8 ? appointment.userId.length : 8,
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/radar'),
        ),
        title: const Text('Active Job'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accepted badge — the only saturated block on this
              // screen, matching the accept CTA's green.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACCEPTED',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bespoke tailoring visit',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Customer · $shortUserId',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _DetailCard(
                icon: Icons.place_outlined,
                label: 'Address',
                value: appointment.address.isEmpty
                    ? '—'
                    : appointment.address,
                trailing: TextButton.icon(
                  onPressed: () => _copyAddress(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(height: 14),
              _DetailCard(
                icon: Icons.schedule,
                label: 'Scheduled time',
                value: _formatScheduledTime(appointment.scheduledTime),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _copyAddress(context),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('OPEN NAVIGATION'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Marking jobs complete ships in the next drop.'),
                    ),
                  );
                },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('MARK COMPLETE'),
              ),
              const SizedBox(height: 24),
              Text(
                'Need help? Call Outfitly Partner Support from inside the app once the route is loaded.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

String _formatScheduledTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d · $hh:$mm';
}
