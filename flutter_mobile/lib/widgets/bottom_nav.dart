import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Shared navigation chrome for the athlete and coach workspaces.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isCoach;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isCoach = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(context: context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.panelRadius),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                if (index == currentIndex) return;
                HapticFeedback.selectionClick();
                onTap(index);
              },
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(isCoach
                        ? Icons.content_paste_outlined
                        : Icons.bar_chart_outlined),
                    selectedIcon: Icon(isCoach
                        ? Icons.content_paste_rounded
                        : Icons.bar_chart_rounded),
                    label: isCoach ? 'Report' : 'Analytics'),
                NavigationDestination(
                    icon: Icon(isCoach
                        ? Icons.list_alt_outlined
                        : Icons.favorite_border_rounded),
                    selectedIcon: Icon(isCoach
                        ? Icons.list_alt_rounded
                        : Icons.favorite_rounded),
                    label: isCoach ? 'Plan' : 'Salute'),
                const NavigationDestination(
                    icon: Icon(Icons.group_outlined),
                    selectedIcon: Icon(Icons.group_rounded),
                    label: 'Team'),
                const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profilo'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
