import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/data/mappers/transport_mappers.dart';

void main() {
  test('VehicleMapper convierte relaciones anidadas y números', () {
    final vehicle = VehicleMapper.fromJson({
      'id': 'vehicle-1',
      'code': 'T-01',
      'plate': 'ABC-123',
      'status': 'active',
      'created_at': '2026-10-14T12:00:00Z',
      'route_id': 'route-1',
      'driver_id': 'driver-1',
      'routes': {'name': 'Centro'},
      'drivers': {
        'profiles': {'full_name': 'María López'},
      },
      'vehicle_locations': {
        'latitude': 19.43,
        'longitude': -99.13,
        'speed': '32.5',
        'heading': 90,
        'updated_at': '2026-10-14T12:01:00Z',
      },
    });

    expect(vehicle.routeName, 'Centro');
    expect(vehicle.driverName, 'María López');
    expect(vehicle.location?.speed, 32.5);
  });

  test('RouteMapper ordena paradas y calcula tarifa máxima', () {
    final route = RouteMapper.fromJson({
      'id': 'route-1',
      'name': 'Centro',
      'origin': 'A',
      'destination': 'B',
      'active': true,
      'created_at': '2026-10-14T12:00:00Z',
      'stops': [
        {
          'id': 's2',
          'route_id': 'route-1',
          'name': 'Dos',
          'latitude': 2,
          'longitude': 2,
          'stop_order': 2,
          'fare': 15,
        },
        {
          'id': 's1',
          'route_id': 'route-1',
          'name': 'Uno',
          'latitude': 1,
          'longitude': 1,
          'stop_order': 1,
          'fare': 10,
        },
      ],
      'vehicles': [
        {'id': 'v1'},
      ],
    });

    expect(route.stops.first.name, 'Uno');
    expect(route.maximumFare, 15);
    expect(route.vehicleCount, 1);
  });
}
