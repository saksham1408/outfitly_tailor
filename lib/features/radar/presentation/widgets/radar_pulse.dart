import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Three concentric rings expanding and fading outward from a central
/// dot — the "listening for nearby requests" affordance on the radar
/// home screen.
///
/// The three rings share one [AnimationController] but each reads the
/// controller's value at a 120° phase offset (0.0, 1/3, 2/3) so the
/// pulses cascade smoothly without any ring sitting idle.
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, this.size = 280});

  /// Outer diameter the rings expand to. Default sized for a typical
  /// 360–412dp phone viewport with healthy margins on either side.
  final double size;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // A static faint halo behind everything — stops the dark
              // canvas from looking empty between pulses.
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.06),
                      AppColors.background.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
              // Three staggered expanding rings.
              _PulseRing(
                phase: (_controller.value) % 1.0,
                maxSize: widget.size,
              ),
              _PulseRing(
                phase: (_controller.value + 1 / 3) % 1.0,
                maxSize: widget.size,
              ),
              _PulseRing(
                phase: (_controller.value + 2 / 3) % 1.0,
                maxSize: widget.size,
              ),
              // Glowing centre dot — the "device" on the radar.
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One expanding-and-fading ring. Rendered at each 120° phase stop.
class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.phase, required this.maxSize});

  final double phase;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    // Start at 40px, grow to (maxSize - 40) over the phase cycle.
    final size = 40 + (maxSize - 80) * phase;
    // Opacity fades from 0.7 at the start to 0 at the end — the
    // classic radar-ripple feel.
    final opacity = (1.0 - phase) * 0.7;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}
