import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/monitoring/monitoring_page.dart';

class _MonitoringRepository implements VehicleRepository {
  @override
  Future<List<Vehicle>> getMonitoredVehicles() async => [
    Vehicle(
      id: 'located',
      code: 'U-01',
      plate: 'ABC-001',
      status: 'active',
      createdAt: DateTime.utc(2026),
      location: VehicleLocation(
        latitude: 19.43,
        longitude: -99.13,
        speed: 20,
        heading: 0,
        updatedAt: DateTime.now(),
      ),
    ),
    Vehicle(
      id: 'missing',
      code: 'U-02',
      plate: 'ABC-002',
      status: 'no_signal',
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _config = AppConfig(
  supabaseUrl: 'https://project.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  requireAdminMfa: false,
  tileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
  osmUserAgent: 'test',
);

void main() {
  testWidgets('error Realtime se muestra con reintento discreto', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          vehicleRepositoryProvider.overrideWithValue(_MonitoringRepository()),
          locationChangesProvider.overrideWith(
            (ref) => Stream.value(
              const LocationMonitorEvent(
                status: RealtimeConnectionStatus.error,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MonitoringPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Tiempo real interrumpido'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 1280.0]) {
    testWidgets('monitoreo a $width conserva unidad sin GPS', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            vehicleRepositoryProvider.overrideWithValue(
              _MonitoringRepository(),
            ),
            locationChangesProvider.overrideWith(
              (ref) => Stream.value(
                const LocationMonitorEvent(
                  status: RealtimeConnectionStatus.connected,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MonitoringPage())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('En vivo'), findsOneWidget);
      if (width < 820) {
        await tester.tap(find.textContaining('Ver 2 unidades'));
        await tester.pump();
      }
      expect(find.text('U-02'), findsOneWidget);
      expect(find.textContaining('Sin señal'), findsWidgets);
      expect(find.byTooltip('Unidad U-02 · no_signal'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
