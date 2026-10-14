import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/core/errors/app_exception.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/auth/configuration_page.dart';
import 'package:traut_admin/presentation/pages/auth/login_page.dart';
import 'package:traut_admin/presentation/pages/dashboard/dashboard_page.dart';

class _SignedOutAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(stage: AuthStage.signedOut);
}

void main() {
  testWidgets('muestra instrucciones cuando falta configuración', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigurationPage(
        config: AppConfig(
          supabaseUrl: '',
          supabasePublishableKey: '',
          requireAdminMfa: false,
          tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          osmUserAgent: 'test',
        ),
      ),
    );
    expect(find.text('Falta configurar Traut Admin'), findsOneWidget);
    expect(find.textContaining('config/dev.json'), findsOneWidget);
  });

  testWidgets('login no ofrece registro administrativo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('Crear cuenta'), findsNothing);
  });

  testWidgets('dashboard muestra métricas proporcionadas', (tester) async {
    const config = AppConfig(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      requireAdminMfa: false,
      tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      osmUserAgent: 'test',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          dashboardProvider.overrideWith(
            (ref) async => const DashboardMetrics(
              totalVehicles: 9,
              activeVehicles: 4,
              maintenanceVehicles: 1,
              noSignalVehicles: 2,
              activeRoutes: 3,
              activeDrivers: 5,
              activeTrips: 2,
              openIncidents: 6,
            ),
          ),
          monitoredVehiclesProvider.overrideWith(
            (ref) => Future.error(const AppException('Sin mapa para prueba')),
          ),
          locationChangesProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unidades totales'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Incidencias pendientes'), findsOneWidget);
  });
}
