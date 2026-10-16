import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  Vehicle vehicle(String status, DateTime? updatedAt, {bool invalid = false}) =>
      Vehicle(
        id: 'v1',
        code: 'U-01',
        plate: 'ABC-123',
        status: status,
        createdAt: now,
        invalidLocationData: invalid,
        location: updatedAt == null
            ? null
            : VehicleLocation(
                latitude: 19,
                longitude: -99,
                speed: 0,
                heading: 0,
                updatedAt: updatedAt,
              ),
      );

  test('distingue reciente, atrasada y sin señal', () {
    expect(
      vehicle(
        'active',
        now.subtract(const Duration(seconds: 30)),
      ).signalState(now),
      VehicleSignalState.recent,
    );
    expect(
      vehicle(
        'active',
        now.subtract(const Duration(minutes: 6)),
      ).signalState(now),
      VehicleSignalState.delayed,
    );
    expect(
      vehicle('no_signal', null).signalState(now),
      VehicleSignalState.noSignal,
    );
  });

  test('GPS recuperado no reactiva estado y datos inválidos se señalan', () {
    expect(
      vehicle('no_signal', now).signalState(now),
      VehicleSignalState.recoveredPendingStatus,
    );
    expect(
      vehicle('active', null, invalid: true).signalState(now),
      VehicleSignalState.invalidData,
    );
    expect(
      vehicle('active', now.add(const Duration(days: 1))).signalState(now),
      VehicleSignalState.invalidData,
    );
  });
}
