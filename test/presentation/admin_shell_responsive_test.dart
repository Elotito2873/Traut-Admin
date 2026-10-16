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
  for (final width in [600.0, 720.0, 800.0, 980.0, 1024.0, 1280.0, 1440.0]) {
    testWidgets('AdminShell sin overflow a $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
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
      if (width == 1280) {
        final collapse = find.byTooltip('Contraer barra lateral');
        await tester.tap(
          collapse.evaluate().isNotEmpty
              ? collapse
              : find.byTooltip('Expandir barra lateral'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
