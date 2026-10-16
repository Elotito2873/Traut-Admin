import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/auth/configuration_page.dart';
import 'package:traut_admin/presentation/pages/auth/login_page.dart';
import 'package:traut_admin/presentation/pages/dashboard/dashboard_page.dart';
import 'package:traut_admin/presentation/pages/settings/settings_page.dart';
import 'package:traut_admin/presentation/widgets/common_widgets.dart';
import 'package:traut_admin/presentation/widgets/transport_map.dart';

class _SignedOutAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(stage: AuthStage.signedOut);
}

class _LightThemeController extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
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
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('callback HTTPS'), findsOneWidget);
  });

  testWidgets('dashboard muestra métricas proporcionadas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unidades totales'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Incidencias pendientes'), findsOneWidget);
    expect(find.byType(TransportMap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, error seguro y paginación caben en ancho estrecho', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 100, child: LoadingPanel()),
              Expanded(
                child: ErrorPanel(
                  error: StateError('detalle interno que no debe mostrarse'),
                  onRetry: () {},
                ),
              ),
              PagedTableFooter<int>(
                result: const PagedResult(
                  items: [1, 2],
                  total: 100,
                  page: 0,
                  pageSize: 10,
                ),
                onPageSize: (_) {},
                onPage: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('detalle interno'), findsNothing);
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ajustes adapta controles y tarjeta MFA en ancho estrecho', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(_LightThemeController.new),
          verifiedTotpProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ThemeMode>), findsOneWidget);
    expect(find.text('Configurar MFA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
