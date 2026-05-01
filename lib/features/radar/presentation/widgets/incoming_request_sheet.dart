import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/tailor_appointment.dart';

/// Slide-up sheet presented the moment a new pending request is
/// detected by the radar stream.
///
/// The sheet blocks interaction with the radar behind it (it's
/// non-dismissible by tapping the scrim — the tailor must explicitly
/// accept or dismiss) and the Accept button is the only visually
/// saturated affordance, so attention goes exactly where we want it.
class IncomingRequestSheet extends StatelessWidget {
  const IncomingRequestSheet({
    super.key,
    required this.appointment,
    required this.onAccept,
    required this.onDismiss,
    this.accepting = false,
  });

  final TailorAppointment appointment;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Marketplace direct requests are a distinct visual beat — the
    // customer hand-picked THIS tailor from the selection screen,
    // and the sheet should make that pride-of-place obvious so the
    // tailor reads it as personal rather than yet another broadcast.
    final isDirect =
        appointment.status == AppointmentStatus.pendingTailorApproval;
    final headline = isDirect ? 'DIRECT REQUEST' : 'NEW REQUEST';
    final subtitle = isDirect
        ? 'Hand-picked from the marketplace'
        : 'Bespoke tailoring visit';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet grabber — tactile hint that this surface came up
            // from below.
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Icon(
                  // Person-check on direct requests, pulsing dot on
                  // broadcasts. The icon swap is what carries the
                  // semantic difference at a glance.
                  isDirect
                      ? Icons.person_pin_circle_rounded
                      : Icons.notifications_active_rounded,
                  size: isDirect ? 18 : 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Text(
                  headline,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 22),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Address',
              value: appointment.address.isEmpty
                  ? '—'
                  : appointment.address,
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Scheduled for',
              value: _formatScheduledTime(appointment.scheduledTime),
            ),
            const SizedBox(height: 28),
            _AcceptButton(
              onPressed: accepting ? null : onAccept,
              loading: accepting,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: accepting ? null : onDismiss,
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'ACCEPT REQUEST',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                  ),
                ],
              ),
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
