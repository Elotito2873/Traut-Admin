import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guardas SQL evitan auditoría falsa al guardar unidades', () {
    final audit = _proposal('002_audit_logs.sql');
    final atomic = _proposal('006_atomic_admin_operations.sql');
    final saveVehicle = atomic.substring(
      atomic.indexOf(
        'create or replace function public.save_vehicle_with_assignment',
      ),
      atomic.indexOf('create or replace function public.reorder_route_stops'),
    );

    expect(audit, contains("if tg_op = 'UPDATE' and old_row = new_row then"));
    expect(audit, contains("else 'change_vehicle_driver'"));
    expect(saveVehicle, contains('previous_driver_id uuid'));
    expect(
      saveVehicle,
      contains('previous_driver_id is distinct from p_driver_id'),
    );
    expect(
      saveVehicle,
      isNot(contains('route_id = p_route_id,\n        driver_id = null')),
    );
  });

  test('no_signal separa wrapper AAL2 y worker privado', () {
    final sql = _proposal('005_no_signal_detection.sql');

    expect(sql, contains('function private.mark_stale_vehicles_no_signal('));
    expect(sql, contains('function public.mark_stale_vehicles_no_signal('));
    expect(sql, contains("<> 'aal2'"));
    expect(
      sql,
      contains('return private.mark_stale_vehicles_no_signal(stale_after);'),
    );
    expect(sql, contains('from public, anon, authenticated;'));
    expect(sql, contains("where vehicle.status = 'active'"));
    expect(sql, contains("location.updated_at >= now() - stale_after"));
  });

  test('ended_at se controla por servidor en INSERT y UPDATE', () {
    final sql = _proposal('008_server_trip_timestamps.sql');

    expect(sql, contains('before insert or update on public.trips'));
    expect(sql, contains("if new.status = 'active' then"));
    expect(sql, contains('new.ended_at := null;'));
    expect(sql, contains("if tg_op = 'INSERT' then"));
    expect(sql, contains('new.ended_at := now();'));
    expect(sql, contains('new.ended_at := old.ended_at;'));
  });
}

String _proposal(String name) =>
    File('database/proposals/$name').readAsStringSync();
