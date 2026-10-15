import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/services/inactivity_timer.dart';
import 'package:traut_admin/core/services/location_change_batcher.dart';

void main() {
  test('InactivityTimer reinicia el plazo al registrar actividad', () async {
    var locks = 0;
    final timer = InactivityTimer(
      timeout: const Duration(milliseconds: 40),
      onTimeout: () => locks++,
    );
    addTearDown(timer.dispose);

    timer.start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    timer.registerActivity();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(locks, 0);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(locks, 1);
  });

  test('LocationChangeBatcher agrupa y elimina IDs repetidos', () async {
    final batches = <Set<String>>[];
    final batcher = LocationChangeBatcher(
      window: const Duration(milliseconds: 20),
      onBatch: batches.add,
    );
    addTearDown(batcher.dispose);

    batcher
      ..add('vehicle-1')
      ..add('vehicle-1')
      ..add('vehicle-2');
    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(batches, hasLength(1));
    expect(batches.single, {'vehicle-1', 'vehicle-2'});
  });
}
