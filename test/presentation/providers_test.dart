import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';

class _VehicleRepository implements VehicleRepository {
  final requested = <Set<String>>[];

  @override
  Future<List<Vehicle>> getMonitoredVehicles() async => [
    _vehicle('vehicle-1', 'U-01', 1),
    _vehicle('vehicle-2', 'U-02', 2),
  ];

  @override
  Future<List<Vehicle>> getMonitoredVehiclesByIds(Set<String> ids) async {
    requested.add(Set.of(ids));
    if (ids.contains('vehicle-2')) {
      return [_vehicle('vehicle-2', 'U-02', 99)];
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'monitoreo mezcla cambios por ID y elimina registros ausentes',
    () async {
      final repository = _VehicleRepository();
      final container = ProviderContainer(
        overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
      );
      final subscription = container.listen(
        monitoredVehiclesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      await container.read(monitoredVehiclesProvider.future);
      await container.read(monitoredVehiclesProvider.notifier).refreshIds({
        'vehicle-2',
      });
      var vehicles = container.read(monitoredVehiclesProvider).requireValue;
      expect(vehicles, hasLength(2));
      expect(
        vehicles.singleWhere((item) => item.id == 'vehicle-2').location!.speed,
        99,
      );

      await container.read(monitoredVehiclesProvider.notifier).refreshIds({
        'vehicle-1',
      });
      vehicles = container.read(monitoredVehiclesProvider).requireValue;
      expect(vehicles.map((item) => item.id), ['vehicle-2']);
      expect(repository.requested, [
        {'vehicle-2'},
        {'vehicle-1'},
      ]);
    },
  );
}

Vehicle _vehicle(String id, String code, double speed) => Vehicle(
  id: id,
  code: code,
  plate: 'ABC-123',
  status: 'active',
  createdAt: DateTime.utc(2026),
  location: VehicleLocation(
    latitude: 19.43,
    longitude: -99.13,
    speed: speed,
    heading: 0,
    updatedAt: DateTime.utc(2026),
  ),
);
