import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/compare/compare_screen.dart';
import 'features/data_sources/data_sources_screen.dart';
import 'features/map/map_screen.dart';
import 'features/reports/report_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/study/study_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/map',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/study', builder: (context, state) => const StudyScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/compare', builder: (context, state) => const CompareScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/data', builder: (context, state) => const DataSourcesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/reports', builder: (context, state) => const ReportScreen()),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell(this.navigationShell, {super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RepaintBoundary(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'الدراسة'),
          NavigationDestination(icon: Icon(Icons.compare_arrows_outlined), selectedIcon: Icon(Icons.compare_arrows), label: 'المقارنة'),
          NavigationDestination(icon: Icon(Icons.source_outlined), selectedIcon: Icon(Icons.source), label: 'البيانات'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
