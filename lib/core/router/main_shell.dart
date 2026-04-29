import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Persistent bottom-nav shell hosting the three primary surfaces:
/// Radar, Earnings, Profile.
///
/// We use [StatefulShellRoute.indexedStack] (go_router 17) so each
/// branch keeps its own navigator stack — switching from Earnings
/// back to Radar preserves any pushed routes (e.g. an in-progress
/// active-job) instead of replaying the build from scratch. That
/// matches the dispatch app's "always-on radar" mental model: the
/// tailor can peek at earnings without losing their place.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  /// Provided by [StatefulShellRoute.indexedStack]. Holds the index
  /// of the active branch and exposes [goBranch] for tab switching.
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    // `initialLocation: true` re-pops to the branch root if the same
    // tab is tapped again — the standard Material BottomNavigationBar
    // affordance.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            backgroundColor: AppColors.background,
            indicatorColor: AppColors.accent.withValues(alpha: 0.16),
            surfaceTintColor: Colors.transparent,
            height: 64,
            labelBehavior:
                NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(
                  Icons.radar_rounded,
                  color: AppColors.textTertiary,
                ),
                selectedIcon: Icon(
                  Icons.radar_rounded,
                  color: AppColors.accent,
                ),
                label: 'Radar',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.textTertiary,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                ),
                label: 'Earnings',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textTertiary,
                ),
                selectedIcon: Icon(
                  Icons.person_rounded,
                  color: AppColors.accent,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
