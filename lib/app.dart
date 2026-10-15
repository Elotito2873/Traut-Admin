import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/providers.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/mfa_page.dart';
import 'presentation/pages/auth/unauthorized_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/drivers/drivers_page.dart';
import 'presentation/pages/fleet/fleet_page.dart';
import 'presentation/pages/incidents/incidents_page.dart';
import 'presentation/pages/monitoring/monitoring_page.dart';
import 'presentation/pages/routes/route_editor_page.dart';
import 'presentation/pages/routes/routes_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/trips/trips_page.dart';
import 'presentation/widgets/admin_shell.dart';
import 'presentation/widgets/inactivity_guard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final administrativeShell = ref.watch(
    authControllerProvider.select(
      (state) =>
          state.stage == AuthStage.authenticated ||
          state.stage == AuthStage.locked,
    ),
  );
  return GoRouter(
    initialLocation: administrativeShell ? '/' : '/access',
    redirect: (context, state) {
      final access = state.matchedLocation == '/access';
      if (!administrativeShell && !access) return '/access';
      if (administrativeShell && access) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/access',
        builder: (context, state) => const _AccessGate(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            InactivityGuard(child: AdminShell(child: child)),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/monitoring',
            builder: (_, _) => const MonitoringPage(),
          ),
          GoRoute(path: '/fleet', builder: (_, _) => const FleetPage()),
          GoRoute(path: '/routes', builder: (_, _) => const RoutesPage()),
          GoRoute(
            path: '/routes/:id',
            builder: (_, state) =>
                RouteEditorPage(routeId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/drivers', builder: (_, _) => const DriversPage()),
          GoRoute(path: '/trips', builder: (_, _) => const TripsPage()),
          GoRoute(path: '/incidents', builder: (_, _) => const IncidentsPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.not_listed_location_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('La página solicitada no existe.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Ir al resumen'),
            ),
          ],
        ),
      ),
    ),
  );
});

class TrautAdminApp extends ConsumerWidget {
  const TrautAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Traut Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _AccessGate extends ConsumerWidget {
  const _AccessGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return switch (state.stage) {
      AuthStage.initializing => Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      ),
      AuthStage.signedOut => const LoginPage(),
      AuthStage.mfaChallenge => const MfaPage(enrollment: false),
      AuthStage.mfaEnrollment => const MfaPage(enrollment: true),
      AuthStage.unauthorized => const UnauthorizedPage(),
      AuthStage.authenticated => const SizedBox.shrink(),
      AuthStage.locked => const SizedBox.shrink(),
    };
  }
}
