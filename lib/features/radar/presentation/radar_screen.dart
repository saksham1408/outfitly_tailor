import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/appointment_service.dart';
import '../domain/tailor_appointment.dart';
import 'widgets/incoming_request_sheet.dart';
import 'widgets/radar_pulse.dart';

/// The tailor's home screen — a dark dispatch-radar UI that listens
/// for nearby requests over Supabase Realtime and slides up a sheet
/// the moment one lands.
///
/// Two subtle details worth calling out:
///
///   1. Supabase's `.stream()` re-emits the **entire** filtered row
///      set on every mutation. Without dedup, the same pending
///      request would trigger the incoming-request sheet every time
///      ANY row changed. We maintain a `_promptedIds` Set so each
///      appointment prompts at most once per session.
///
///   2. The sheet is shown via [WidgetsBinding.addPostFrameCallback]
///      — doing it directly inside the StreamBuilder builder would
///      call `showModalBottomSheet` during the build phase, which is
///      illegal. The callback defers it to the next frame.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final AppointmentService _service = AppointmentService();

  /// IDs we've already surfaced to the user this session. Prevents
  /// the BottomSheet from redisplaying when the stream re-emits.
  final Set<String> _promptedIds = <String>{};

  /// Lock so we never stack two sheets on top of each other.
  bool _sheetVisible = false;

  bool _accepting = false;

  Future<void> _handleAccept(TailorAppointment appt) async {
    if (_accepting) return;
    setState(() => _accepting = true);

    try {
      final claimed = await _service.acceptRequest(appt.id);

      if (!mounted) return;

      if (claimed == null) {
        // Race lost — another tailor beat us to it.
        Navigator.of(context).pop(); // Close sheet.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That request was already taken by another tailor.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close the incoming sheet.
      context.pushNamed('activeJob', extra: claimed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept — please try again.')),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _maybeShowIncoming(BuildContext context, TailorAppointment appt) {
    if (_sheetVisible) return;
    if (_promptedIds.contains(appt.id)) return;

    _promptedIds.add(appt.id);
    _sheetVisible = true;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, _) => IncomingRequestSheet(
            appointment: appt,
            accepting: _accepting,
            onAccept: () => _handleAccept(appt),
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _sheetVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Radar'),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: StreamBuilder<List<TailorAppointment>>(
        stream: _service.pendingRequests(),
        builder: (context, snapshot) {
          final pending = snapshot.data ?? const <TailorAppointment>[];

          // Surface the first un-prompted pending request, if any.
          if (pending.isNotEmpty) {
            final next = pending.firstWhere(
              (a) => !_promptedIds.contains(a.id),
              orElse: () => pending.first,
            );
            if (!_promptedIds.contains(next.id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _maybeShowIncoming(context, next);
              });
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'ONLINE',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You are on the dispatch network',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Center(child: RadarPulse()),
                const SizedBox(height: 40),
                Text(
                  'Listening for nearby requests…',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep the app open. You will be notified the moment a customer requests a bespoke tailoring visit nearby.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                _PendingBadge(count: pending.length),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = count == 0
        ? 'No pending requests'
        : '$count pending request${count == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: count == 0 ? AppColors.textTertiary : AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
