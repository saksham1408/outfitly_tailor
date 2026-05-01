import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/appointment_service.dart';
import '../domain/tailor_appointment.dart';

/// Rendered immediately after a successful accept. Shows the job the
/// tailor just claimed — customer details, address, scheduled time —
/// and the four-step progression stepper that drives the customer's
/// live tracking screen on the other side of the wire.
///
/// The screen owns the appointment as local state so the stepper can
/// re-render the moment the tailor advances a step. We don't subscribe
/// to a Realtime stream here because the Partner is the only writer
/// for accepted → completed transitions — the only external actor that
/// could mutate the row is the customer cancelling, which we surface
/// only when the next progress call returns null (RLS guards block it).
///
/// `url_launcher` for handing off the address to Google/Apple Maps
/// is deliberately deferred to a later drop; today the button copies
/// the address to the clipboard so the tailor can paste it wherever
/// they prefer. That keeps this first cut dependency-light.
class ActiveJobScreen extends StatefulWidget {
  const ActiveJobScreen({super.key, required this.appointment});

  final TailorAppointment appointment;

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  late TailorAppointment _appointment;
  final _service = AppointmentService();
  bool _progressing = false;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
  }

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _appointment.address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  /// Advance the job to the next state. The button label is derived
  /// from [AppointmentStatus.nextForward] so we never need to special-
  /// case "is this the final step?" here — just call progressJob and
  /// trust the enum.
  ///
  /// Failure handling: [AppointmentService.progressJob] throws a typed
  /// [ProgressJobException] when the UPDATE matches zero rows, so we
  /// can show the *specific* reason (cancelled vs. session swap vs.
  /// stale screen) instead of the old generic "no longer active"
  /// catch-all that hid three different bugs behind one message.
  ///
  /// `staleStatus` is the only reason we DON'T bounce to the radar —
  /// that one's recoverable by re-syncing the local state to whatever
  /// the DB actually says, so the tailor can keep going from there.
  Future<void> _advance() async {
    final next = _appointment.status.nextForward;
    if (next == null || _progressing) return;

    setState(() => _progressing = true);
    try {
      final updated = await _service.progressJob(
        appointmentId: _appointment.id,
        expectedFrom: _appointment.status,
        to: next,
      );

      if (!mounted) return;
      setState(() => _appointment = updated);

      // If we just landed on `completed`, kick the tailor back to the
      // radar after a beat so they can pick up the next request.
      if (updated.status == AppointmentStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job marked complete. Nice work.')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        context.go('/radar');
      }
    } on ProgressJobException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      // Bounce back to the radar for everything except `staleStatus`,
      // which is recoverable — re-sync local state and stay put.
      if (e.reason == ProgressJobFailure.staleStatus) {
        // Pull the row's actual current state and rebuild the screen.
        // The tailor can press the (now-correctly-labelled) CTA to
        // continue from wherever they actually are.
        await _refetchAppointment();
      } else {
        context.go('/radar');
      }
    } catch (e) {
      // Network / unknown failure — show it but don't kick the tailor
      // out, since the job state is unchanged. They can retry.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  /// Re-read the appointment row and rebuild local state so the
  /// stepper + CTA reflect the DB's truth. Called after a
  /// `staleStatus` failure (typically: hot-reload survivor or a
  /// manual DB tweak) so the screen self-heals without forcing the
  /// tailor back to the radar.
  Future<void> _refetchAppointment() async {
    try {
      final fresh = await _service.fetchById(_appointment.id);
      if (!mounted || fresh == null) return;
      setState(() => _appointment = fresh);
    } catch (_) {
      // Best-effort; if we can't refetch, the existing snackbar copy
      // already pointed the tailor at "pull to refresh".
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shortUserId = _appointment.userId.isEmpty
        ? '—'
        : _appointment.userId.substring(
            0,
            _appointment.userId.length < 8 ? _appointment.userId.length : 8,
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
              _StatusBadge(status: _appointment.status),
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
              const SizedBox(height: 24),
              _ProgressStepper(status: _appointment.status),
              const SizedBox(height: 28),
              _DetailCard(
                icon: Icons.place_outlined,
                label: 'Address',
                value: _appointment.address.isEmpty
                    ? '—'
                    : _appointment.address,
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
                value: _formatScheduledTime(_appointment.scheduledTime),
              ),
              const SizedBox(height: 32),
              _PrimaryCta(
                status: _appointment.status,
                progressing: _progressing,
                onAdvance: _advance,
                onOpenNavigation: () => _copyAddress(context),
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

// ────────────────────────────────────────────────────────────
// Status badge — matches the old ACCEPTED pill but reflects
// whichever stage we're currently at, including the terminal
// COMPLETED / CANCELLED resting states.
// ────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, icon) = _badgeFor(status);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: text.labelMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData) _badgeFor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.pending:
        return ('PENDING', Icons.hourglass_empty);
      case AppointmentStatus.pendingTailorApproval:
        return ('AWAITING YOU', Icons.person_pin_circle_rounded);
      case AppointmentStatus.accepted:
        return ('ACCEPTED', Icons.check_circle);
      case AppointmentStatus.enRoute:
        return ('EN ROUTE', Icons.directions_car);
      case AppointmentStatus.arrived:
        return ('ARRIVED', Icons.location_on);
      case AppointmentStatus.completed:
        return ('COMPLETED', Icons.done_all);
      case AppointmentStatus.cancelled:
        return ('CANCELLED', Icons.cancel);
    }
  }
}

// ────────────────────────────────────────────────────────────
// Progress stepper — horizontal four-node strip showing
// Accepted → En route → Arrived → Completed. Filled circles
// for steps ≤ current, ghosted for upcoming. The connector
// between nodes also fills as the job advances.
// ────────────────────────────────────────────────────────────
class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});

  final AppointmentStatus status;

  // Step 0 (pending) is implicit — by the time the screen renders we've
  // already accepted, so the stepper begins at "Accepted". The zero-
  // indexed positions here therefore are: 0=Accepted, 1=En route,
  // 2=Arrived, 3=Completed.
  static const _steps = <(String, IconData)>[
    ('Accepted', Icons.check),
    ('En route', Icons.directions_car),
    ('Arrived', Icons.location_on),
    ('Done', Icons.done_all),
  ];

  @override
  Widget build(BuildContext context) {
    // Map the global progressIndex (which counts pending=0) onto the
    // stepper's local 4-node index (where accepted=0).
    final localIdx = status == AppointmentStatus.cancelled
        ? -1
        : (status.progressIndex - 1).clamp(0, _steps.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            // Even indices are the nodes, odd indices are the connectors.
            if (i.isEven) {
              final stepIdx = i ~/ 2;
              final reached = stepIdx <= localIdx;
              return _StepNode(
                label: _steps[stepIdx].$1,
                icon: _steps[stepIdx].$2,
                reached: reached,
                current: stepIdx == localIdx,
              );
            } else {
              final connectorIdx = i ~/ 2;
              final filled = connectorIdx < localIdx;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: filled
                      ? AppColors.accent
                      : AppColors.divider,
                ),
              );
            }
          }),
        );
      },
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.icon,
    required this.reached,
    required this.current,
  });

  final String label;
  final IconData icon;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fill = reached ? AppColors.accent : AppColors.surface;
    final iconColor = reached ? Colors.white : AppColors.textTertiary;
    final border = current
        ? AppColors.accent
        : (reached ? AppColors.accent : AppColors.divider);

    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: current ? 2.5 : 1.5),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: reached
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Primary CTA — reads the current status to decide which label
// to show, and disables itself if there's nothing to do (e.g.
// already completed).
// ────────────────────────────────────────────────────────────
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.status,
    required this.progressing,
    required this.onAdvance,
    required this.onOpenNavigation,
  });

  final AppointmentStatus status;
  final bool progressing;
  final VoidCallback onAdvance;
  final VoidCallback onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    // Terminal states: just show navigation as a courtesy and a
    // disabled forward button.
    if (status == AppointmentStatus.completed ||
        status == AppointmentStatus.cancelled) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: onOpenNavigation,
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('OPEN NAVIGATION'),
          ),
        ],
      );
    }

    final (advanceLabel, advanceIcon) = _ctaFor(status);

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: progressing ? null : onAdvance,
          icon: progressing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(advanceIcon),
          label: Text(advanceLabel),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenNavigation,
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('OPEN NAVIGATION'),
        ),
      ],
    );
  }

  (String, IconData) _ctaFor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.accepted:
        return ('I\'M ON THE WAY', Icons.directions_car);
      case AppointmentStatus.enRoute:
        return ('I\'VE ARRIVED', Icons.location_on);
      case AppointmentStatus.arrived:
        return ('MARK COMPLETE', Icons.done_all_rounded);
      // The terminal/initial cases are filtered out at the call
      // site — return a sane fallback rather than crashing.
      case AppointmentStatus.pending:
      case AppointmentStatus.pendingTailorApproval:
      case AppointmentStatus.completed:
      case AppointmentStatus.cancelled:
        return ('CONTINUE', Icons.arrow_forward);
    }
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
