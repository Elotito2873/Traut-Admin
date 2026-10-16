import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traut_admin/app.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/domain/entities/admin_profile.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/widgets/admin_shell.dart';

class _AdminAuthController extends AuthController {
  @override
  AuthViewState build() => const AuthViewState(
    stage: AuthStage.authenticated,
    profile: AdminProfile(
      id: 'admin',
      fullName: 'Administrador',
      email: 'admin@example.com',
      role: 'admin',
    ),
  );
}

const _config = AppConfig(
  supabaseUrl: 'https://project.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  requireAdminMfa: true,
  tileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
  osmUserAgent: 'test',
);

void main() {
  for (final viewport in [
    (800.0, 600.0),
    (1024.0, 768.0),
    (1366.0, 768.0),
    (1920.0, 1080.0),
  ]) {
    testWidgets('AdminShell sin overflow a ${viewport.$1}x${viewport.$2}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(viewport.$1, viewport.$2);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            authControllerProvider.overrideWith(_AdminAuthController.new),
            dashboardProvider.overrideWith(
              (ref) async => const DashboardMetrics(
                totalVehicles: 3,
                activeVehicles: 2,
                maintenanceVehicles: 0,
                noSignalVehicles: 1,
                activeRoutes: 2,
                activeDrivers: 2,
                activeTrips: 1,
                openIncidents: 0,
              ),
            ),
          ],
          child: const TrautAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resumen'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (viewport.$1 >= 980) {
        final sidebar = find.byKey(const ValueKey('admin-sidebar'));
        final sidebarHeader = find.byKey(
          const ValueKey('admin-sidebar-header'),
        );
        final mainHeader = find.byKey(const ValueKey('admin-main-header'));
        expect(tester.getSize(sidebar).width, expandedSidebarWidth);
        expect(tester.getSize(sidebarHeader).height, adminHeaderHeight);
        expect(tester.getSize(mainHeader).height, adminHeaderHeight);

        await tester.tap(find.byTooltip('Contraer barra lateral'));
        await tester.pump();

        expect(tester.getSize(sidebar).width, collapsedSidebarWidth);
        expect(
          find.descendant(
            of: sidebarHeader,
            matching: find.byTooltip('Expandir barra lateral'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Expandir barra lateral'));
        await tester.pumpAndSettle();
        expect(tester.getSize(sidebar).width, expandedSidebarWidth);
      } else {
        expect(find.byTooltip('Abrir navegación'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('sidebar tolera diez alternancias sin animar el ancho raíz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 768);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          authControllerProvider.overrideWith(_AdminAuthController.new),
          dashboardProvider.overrideWith(
            (ref) async => const DashboardMetrics(
              totalVehicles: 3,
              activeVehicles: 2,
              maintenanceVehicles: 0,
              noSignalVehicles: 1,
              activeRoutes: 2,
              activeDrivers: 2,
              activeTrips: 1,
              openIncidents: 0,
            ),
          ),
        ],
        child: const TrautAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 10; index++) {
      final expanded = index.isEven;
      await tester.tap(
        find.byTooltip(
          expanded ? 'Contraer barra lateral' : 'Expandir barra lateral',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('admin-sidebar'))).width,
        expanded ? collapsedSidebarWidth : expandedSidebarWidth,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
