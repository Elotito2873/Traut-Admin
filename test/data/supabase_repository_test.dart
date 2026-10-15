import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traut_admin/data/repositories/supabase_repositories.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';

void main() {
  test('getMetrics obtiene conteos sin descargar filas', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final table = request.url.pathSegments.last;
      final status = request.url.queryParameters['status'] ?? '';
      final count = switch ((table, status)) {
        ('vehicles', '') => 9,
        ('vehicles', 'eq.active') => 4,
        ('vehicles', 'eq.maintenance') => 1,
        ('vehicles', 'eq.no_signal') => 2,
        ('routes', 'eq.true') => 3,
        ('drivers', 'eq.active') => 5,
        ('trips', 'eq.active') => 2,
        ('incidents', _) => 6,
        _ => 0,
      };
      return http.Response(
        '',
        200,
        headers: {'content-range': '0-0/$count'},
        request: request,
      );
    });
    final supabase = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: client,
    );
    final repository = SupabaseAdminRepository(supabase);

    final metrics = await repository.getMetrics();

    expect(metrics.totalVehicles, 9);
    expect(metrics.activeVehicles, 4);
    expect(metrics.openIncidents, 6);
    expect(requests, hasLength(8));
    expect(requests.every((request) => request.method == 'HEAD'), isTrue);
  });

  test('asignación usa un único RPC y no UPDATE parciales', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });

    await repository.assignDriverVehicle('driver-1', 'vehicle-1');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/assign_driver_to_vehicle');
    expect(requests.single.body, contains('"p_driver_id":"driver-1"'));
    expect(requests.single.body, contains('"p_vehicle_id":"vehicle-1"'));
  });

  test('guardado de unidad envía ruta y conductor en un único RPC', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });

    await repository.saveVehicle(
      id: 'vehicle-1',
      code: ' unit-01 ',
      plate: ' abc-123 ',
      status: 'active',
      routeId: 'route-1',
      driverId: 'driver-1',
    );

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/save_vehicle_with_assignment',
    );
    expect(requests.single.body, contains('"p_vehicle_id":"vehicle-1"'));
    expect(requests.single.body, contains('"p_route_id":"route-1"'));
    expect(requests.single.body, contains('"p_driver_id":"driver-1"'));
    expect(requests.single.body, contains('"p_code":"UNIT-01"'));
    expect(requests.single.body, contains('"p_plate":"ABC-123"'));
  });

  test('reordenamiento usa un único RPC con la ruta y todos los IDs', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final stops = [_stop('stop-2', 2), _stop('stop-1', 1)];

    await repository.reorderStops(stops);

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/reorder_route_stops');
    expect(requests.single.body, contains('"p_route_id":"route-1"'));
    expect(requests.single.body, contains('"p_stop_ids":["stop-2","stop-1"]'));
  });

  test('viajes usa paginación real de servidor y count exacto', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return http.Response(
        '[]',
        200,
        headers: {
          'content-type': 'application/json',
          'content-range': '50-74/125',
        },
        request: request,
      );
    });

    final result = await repository.getTrips(page: 2, pageSize: 25);

    expect(result.items, isEmpty);
    expect(result.total, 125);
    expect(result.page, 2);
    expect(captured.url.queryParameters['offset'], '50');
    expect(captured.url.queryParameters['limit'], '25');
  });

  test('conductores e incidencias también envían range al servidor', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response(
        '[]',
        200,
        headers: {
          'content-type': 'application/json',
          'content-range': '10-19/40',
        },
        request: request,
      );
    });

    final drivers = await repository.getDrivers(page: 1, pageSize: 10);
    final incidents = await repository.getIncidents(page: 1, pageSize: 10);

    expect(drivers.total, 40);
    expect(incidents.total, 40);
    expect(requests, hasLength(2));
    expect(
      requests.every(
        (request) =>
            request.url.queryParameters['offset'] == '10' &&
            request.url.queryParameters['limit'] == '10',
      ),
      isTrue,
    );
  });

  test('extrae vehicle_id del payload nuevo o anterior de Realtime', () {
    expect(
      vehicleIdFromLocationChange({'vehicle_id': 'vehicle-new'}, const {}),
      'vehicle-new',
    );
    expect(
      vehicleIdFromLocationChange(const {}, {'vehicle_id': 'vehicle-old'}),
      'vehicle-old',
    );
  });
}

SupabaseAdminRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseAdminRepository(
    SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient(handler),
    ),
  );
}

RouteStop _stop(String id, int order) => RouteStop(
  id: id,
  routeId: 'route-1',
  name: id,
  latitude: 19,
  longitude: -99,
  order: order,
  fare: 10,
);
