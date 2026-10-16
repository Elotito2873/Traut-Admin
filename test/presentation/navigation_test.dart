import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traut_admin/app.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/domain/entities/admin_profile.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/auth/login_page.dart';
import 'package:traut_admin/presentation/pages/dashboard/dashboard_page.dart';
import 'package:traut_admin/presentation/pages/fleet/fleet_page.dart';

class _SignedOutAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(stage: AuthStage.signedOut);
}

class _AdminAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(
    stage: AuthStage.authenticated,
    profile: AdminProfile(
      id: 'admin',
      fullName: 'Admin',
      email: 'admin@example.com',
      role: 'admin',
    ),
  );
}

class _CachedRepositories implements DashboardRepository, VehicleRepository {
  int dashboardCalls = 0;
  int vehicleCalls = 0;

  @override
  Future<DashboardMetrics> getMetrics() async {
    dashboardCalls++;
    return const DashboardMetrics(
      totalVehicles: 0,
      activeVehicles: 0,
      maintenanceVehicles: 0,
      noSignalVehicles: 0,
      activeRoutes: 0,
      activeDrivers: 0,
      activeTrips: 0,
      openIncidents: 0,
    );
  }

  @override
  Future<PagedResult<Vehicle>> getVehicles({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
    String? availableForDriverId,
    String sortBy = 'code',
    bool ascending = true,
  }) async {
    vehicleCalls++;
    return PagedResult(
      items: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _config = AppConfig(
  supabaseUrl: 'https://project.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  requireAdminMfa: true,
  tileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
  osmUserAgent: 'test',
);

void main() {
  testWidgets('una ruta administrativa manual redirige al acceso', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const TrautAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginPage));
    GoRouter.of(context).go('/fleet');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(FleetPage), findsNothing);
  });

  testWidgets('volver a una sección reutiliza sus datos durante la sesión', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositories = _CachedRepositories();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          authControllerProvider.overrideWith(_AdminAuthController.new),
          dashboardRepositoryProvider.overrideWithValue(repositories),
          vehicleRepositoryProvider.overrideWithValue(repositories),
        ],
        child: const TrautAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(repositories.dashboardCalls, 1);

    GoRouter.of(tester.element(find.byType(DashboardPage))).go('/fleet');
    await tester.pumpAndSettle();
    expect(find.byType(FleetPage), findsOneWidget);
    expect(repositories.vehicleCalls, 1);

    GoRouter.of(tester.element(find.byType(FleetPage))).go('/');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(DashboardPage))).go('/fleet');
    await tester.pumpAndSettle();

    expect(find.byType(FleetPage), findsOneWidget);
    expect(repositories.dashboardCalls, 1);
    expect(repositories.vehicleCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
