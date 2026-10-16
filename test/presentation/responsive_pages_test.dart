import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/drivers/drivers_page.dart';
import 'package:traut_admin/presentation/pages/fleet/fleet_page.dart';
import 'package:traut_admin/presentation/pages/incidents/incidents_page.dart';
import 'package:traut_admin/presentation/pages/routes/routes_page.dart';
import 'package:traut_admin/presentation/pages/trips/trips_page.dart';

class _Vehicles implements VehicleRepository {
  @override
  Future<PagedResult<Vehicle>> getVehicles({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
    String? availableForDriverId,
    String sortBy = 'code',
    bool ascending = true,
  }) async => PagedResult(
    items: [
      Vehicle(
        id: 'v1',
        code: 'U-01',
        plate: 'ABC-001',
        status: 'active',
        createdAt: DateTime.utc(2026),
      ),
    ],
    total: 1,
    page: page,
    pageSize: pageSize,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drivers implements DriverRepository {
  @override
  Future<PagedResult<Driver>> getDrivers({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
  }) async => PagedResult(
    items: [
      Driver(
        id: 'd1',
        profileId: 'p1',
        fullName: 'Conductor de prueba',
        email: 'conductor@example.com',
        status: 'active',
        createdAt: DateTime.utc(2026),
      ),
    ],
    total: 1,
    page: page,
    pageSize: pageSize,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes implements RouteRepository {
  @override
  Future<List<TransportRoute>> getRoutes({String search = ''}) async => [
    TransportRoute(
      id: 'r1',
      name: 'Centro',
      origin: 'Origen',
      destination: 'Destino',
      color: '#4F46E5',
      active: true,
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Incidents implements IncidentRepository {
  @override
  Future<PagedResult<Incident>> getIncidents({
    required int page,
    required int pageSize,
    String? status,
  }) async => PagedResult(
    items: [
      Incident(
        id: 'i1',
        type: 'Retraso',
        status: 'open',
        createdAt: DateTime.utc(2026),
        description: 'Reporte de prueba',
      ),
    ],
    total: 1,
    page: page,
    pageSize: pageSize,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Trips implements TripRepository {
  @override
  Future<PagedResult<Trip>> getTrips({
    required int page,
    required int pageSize,
    String? status,
  }) async => PagedResult(
    items: [
      Trip(
        id: 't1',
        status: 'active',
        createdAt: DateTime.utc(2026),
        vehicleCode: 'U-01',
        routeName: 'Centro',
      ),
    ],
    total: 1,
    page: page,
    pageSize: pageSize,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [600.0, 720.0, 800.0, 980.0, 1024.0, 1280.0, 1440.0]) {
    testWidgets('listados administrativos sin overflow a $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final page in [
        const FleetPage(),
        const DriversPage(),
        const RoutesPage(),
        const TripsPage(),
        const IncidentsPage(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vehicleRepositoryProvider.overrideWithValue(_Vehicles()),
              driverRepositoryProvider.overrideWithValue(_Drivers()),
              routeRepositoryProvider.overrideWithValue(_Routes()),
              tripRepositoryProvider.overrideWithValue(_Trips()),
              incidentRepositoryProvider.overrideWithValue(_Incidents()),
            ],
            child: MaterialApp(home: Scaffold(body: page)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} @ $width',
        );
      }
    });
  }
}
