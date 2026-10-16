import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/services/location_change_batcher.dart';
import '../../domain/entities/admin_profile.dart';
import '../../domain/entities/transport_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../mappers/transport_mappers.dart';

const _vehicleSelect = '''
id,code,plate,status,route_id,driver_id,created_at,
routes(name),
drivers(id,profiles(full_name)),
vehicle_locations(latitude,longitude,speed,heading,updated_at)
''';

String? vehicleIdFromLocationChange(
  Map<String, dynamic> newRecord,
  Map<String, dynamic> oldRecord,
) {
  return newRecord['vehicle_id']?.toString() ??
      oldRecord['vehicle_id']?.toString();
}

String? verifiedTotpId(Iterable<Factor> factors) {
  for (final factor in factors) {
    if (factor.factorType == FactorType.totp &&
        factor.status == FactorStatus.verified) {
      return factor.id;
    }
  }
  return null;
}

Iterable<String> abandonedTotpIds(Iterable<Factor> factors) => factors
    .where(
      (factor) =>
          factor.factorType == FactorType.totp &&
          factor.status == FactorStatus.unverified,
    )
    .map((factor) => factor.id);

RealtimeConnectionStatus realtimeConnectionStatus(
  RealtimeSubscribeStatus status,
) => switch (status) {
  RealtimeSubscribeStatus.subscribed => RealtimeConnectionStatus.connected,
  RealtimeSubscribeStatus.timedOut => RealtimeConnectionStatus.timeout,
  RealtimeSubscribeStatus.channelError => RealtimeConnectionStatus.error,
  RealtimeSubscribeStatus.closed => RealtimeConnectionStatus.closed,
};

class SupabaseAdminRepository
    implements
        AuthRepository,
        DashboardRepository,
        VehicleRepository,
        RouteRepository,
        DriverRepository,
        IncidentRepository,
        TripRepository,
        SearchRepository {
  SupabaseAdminRepository(this._client, {this.aal2Check});

  final SupabaseClient _client;
  final bool Function()? aal2Check;

  void _requireAal2() {
    if (!(aal2Check?.call() ??
        (_client.auth.currentSession != null && hasAal2))) {
      throw const AppException(
        'Completa la verificación MFA para modificar datos administrativos.',
        code: 'aal2_required',
      );
    }
  }

  String _safeTerm(String input) => input
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AppException(
        'Correo o contraseña incorrectos.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<AdminProfile?> currentAdmin() async {
    final user = _client.auth.currentSession?.user;
    if (user == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select('id,full_name,email,role,avatar_preset')
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      return ProfileMapper.fromJson(data);
    } on PostgrestException catch (error) {
      throw AppException(
        'No fue posible verificar los permisos de esta cuenta.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<MfaGate> mfaRequirement({required bool forceEnrollment}) async {
    final factors = await _client.auth.mfa.listFactors();
    final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    final factorId = verifiedTotpId(factors.all);
    if (factorId == null) {
      return MfaGate(
        forceEnrollment ? MfaRequirement.enrollment : MfaRequirement.none,
      );
    }
    if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
      return MfaGate(MfaRequirement.challenge, factorId: factorId);
    }
    return const MfaGate(MfaRequirement.none);
  }

  @override
  bool get hasAal2 =>
      _client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
      AuthenticatorAssuranceLevels.aal2;

  @override
  Future<MfaEnrollment> enrollMfa() async {
    final factors = await _client.auth.mfa.listFactors();
    if (verifiedTotpId(factors.all) != null) {
      throw const AppException('Tu cuenta ya tiene MFA configurado.');
    }
    for (final id in abandonedTotpIds(factors.all)) {
      await _client.auth.mfa.unenroll(id);
    }
    final response = await _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Traut Admin',
      friendlyName: 'Traut Admin',
    );
    final totp = response.totp;
    if (totp == null) {
      throw const AppException('Supabase no devolvió un factor TOTP válido.');
    }
    return MfaEnrollment(
      factorId: response.id,
      qrCode: totp.qrCode,
      secret: totp.secret,
    );
  }

  @override
  Future<void> verifyMfa({
    required String factorId,
    required String code,
  }) async {
    try {
      await _client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code.trim(),
      );
    } on AuthException catch (error) {
      throw AppException(
        'El código no es válido o ya expiró.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<String?> verifiedTotpFactorId() async {
    final factors = await _client.auth.mfa.listFactors();
    return verifiedTotpId(factors.all);
  }

  @override
  Future<void> unenrollMfa(String factorId) async {
    await _client.auth.mfa.unenroll(factorId);
  }

  Future<int> _count(
    String table, {
    String? column,
    Object? equals,
    String? inColumn,
    List<Object>? inValues,
  }) async {
    dynamic query = _client.from(table).count(CountOption.exact);
    if (column != null && equals != null) query = query.eq(column, equals);
    if (inColumn != null && inValues != null) {
      query = query.inFilter(inColumn, inValues);
    }
    return await query as int;
  }

  @override
  Future<DashboardMetrics> getMetrics() async {
    final values = await Future.wait<int>([
      _count('vehicles'),
      _count('vehicles', column: 'status', equals: 'active'),
      _count('vehicles', column: 'status', equals: 'maintenance'),
      _count('vehicles', column: 'status', equals: 'no_signal'),
      _count('routes', column: 'active', equals: true),
      _count('drivers', column: 'status', equals: 'active'),
      _count('trips', column: 'status', equals: 'active'),
      _count(
        'incidents',
        inColumn: 'status',
        inValues: const ['open', 'reviewing'],
      ),
    ]);
    return DashboardMetrics(
      totalVehicles: values[0],
      activeVehicles: values[1],
      maintenanceVehicles: values[2],
      noSignalVehicles: values[3],
      activeRoutes: values[4],
      activeDrivers: values[5],
      activeTrips: values[6],
      openIncidents: values[7],
    );
  }

  @override
  Future<PagedResult<Vehicle>> getVehicles({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
    String? availableForDriverId,
    String sortBy = 'code',
    bool ascending = true,
  }) async {
    dynamic query = _client.from('vehicles').select(_vehicleSelect);
    final term = _safeTerm(search);
    if (term.isNotEmpty) {
      query = query.or('code.ilike.%$term%,plate.ilike.%$term%');
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (availableForDriverId != null) {
      query = query.or('driver_id.is.null,driver_id.eq.$availableForDriverId');
    }
    final safeSort = const {'code', 'plate', 'created_at'}.contains(sortBy)
        ? sortBy
        : 'code';
    final response = await query
        .order(safeSort, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count();
    final data = (response.data as List)
        .whereType<Map>()
        .map((row) => VehicleMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return PagedResult(
      items: data,
      total: response.count,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Vehicle>> getMonitoredVehicles() async {
    const pageSize = 500;
    final vehicles = <Vehicle>[];
    for (var page = 0; ; page++) {
      final data = await _client
          .from('vehicles')
          .select(_vehicleSelect)
          .inFilter('status', const ['active', 'no_signal', 'maintenance'])
          .order('code')
          .order('id')
          .range(page * pageSize, (page + 1) * pageSize - 1);
      vehicles.addAll(
        data.whereType<Map>().map(
          (row) => VehicleMapper.fromJson(Map<String, dynamic>.from(row)),
        ),
      );
      if (data.length < pageSize) break;
    }
    return vehicles;
  }

  @override
  Future<List<Vehicle>> getMonitoredVehiclesByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final vehicles = <Vehicle>[];
    final idList = ids.toList(growable: false);
    for (var start = 0; start < idList.length; start += 100) {
      final data = await _client
          .from('vehicles')
          .select(_vehicleSelect)
          .inFilter('id', idList.skip(start).take(100).toList())
          .inFilter('status', const ['active', 'no_signal', 'maintenance']);
      vehicles.addAll(
        data.whereType<Map>().map(
          (row) => VehicleMapper.fromJson(Map<String, dynamic>.from(row)),
        ),
      );
    }
    return vehicles;
  }

  @override
  Stream<LocationMonitorEvent> watchLocations() {
    late final StreamController<LocationMonitorEvent> controller;
    late final RealtimeChannel channel;
    late final LocationChangeBatcher batcher;
    var connectionStatus = RealtimeConnectionStatus.reconnecting;
    var disconnectedAfterSubscribe = false;
    controller = StreamController<LocationMonitorEvent>(
      onListen: () {
        controller.add(const LocationMonitorEvent());
        batcher = LocationChangeBatcher(
          window: const Duration(milliseconds: 750),
          onBatch: (ids) {
            if (!controller.isClosed) {
              controller.add(
                LocationMonitorEvent(ids: ids, status: connectionStatus),
              );
            }
          },
        );
        channel = _client
            .channel('admin-vehicle-locations')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vehicle_locations',
              callback: (payload) {
                final vehicleId = vehicleIdFromLocationChange(
                  payload.newRecord,
                  payload.oldRecord,
                );
                if (vehicleId != null) batcher.add(vehicleId);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vehicles',
              callback: (payload) {
                final id =
                    payload.newRecord['id']?.toString() ??
                    payload.oldRecord['id']?.toString();
                if (id != null) batcher.add(id);
              },
            )
            .subscribe((subscribeStatus, error) {
              if (controller.isClosed) return;
              final previous = connectionStatus;
              final next = realtimeConnectionStatus(subscribeStatus);
              if (next != RealtimeConnectionStatus.connected &&
                  previous == RealtimeConnectionStatus.connected) {
                disconnectedAfterSubscribe = true;
              }
              connectionStatus = next;
              controller.add(
                LocationMonitorEvent(
                  status: next,
                  refreshAll:
                      next == RealtimeConnectionStatus.connected &&
                      disconnectedAfterSubscribe,
                ),
              );
              if (next == RealtimeConnectionStatus.connected) {
                disconnectedAfterSubscribe = false;
              }
            });
      },
      onCancel: () async {
        batcher.dispose();
        await _client.removeChannel(channel);
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<int> markStaleVehiclesNoSignal() async {
    _requireAal2();
    try {
      final result = await _client.rpc('mark_stale_vehicles_no_signal');
      return result is num ? result.toInt() : 0;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AppException(
          'Completa MFA y confirma tus permisos antes de revisar la señal.',
        );
      }
      throw const AppException(
        'No fue posible revisar las unidades sin señal.',
      );
    }
  }

  @override
  Future<void> saveVehicle({
    String? id,
    required String code,
    required String plate,
    required String status,
    String? routeId,
    String? driverId,
  }) async {
    _requireAal2();
    await _atomicRpc('save_vehicle_with_assignment', {
      'p_vehicle_id': id,
      'p_code': code.trim().toUpperCase(),
      'p_plate': plate.trim().toUpperCase(),
      'p_status': status,
      'p_route_id': routeId,
      'p_driver_id': driverId,
    });
  }

  @override
  Future<void> updateVehicleStatus(String id, String status) async {
    _requireAal2();
    await _client.from('vehicles').update({'status': status}).eq('id', id);
  }

  @override
  Future<List<TransportRoute>> getRoutes({String search = ''}) async {
    dynamic query = _client.from('routes').select('''
      id,name,origin,destination,color,active,created_at,
      stops(id,route_id,name,latitude,longitude,stop_order,fare),
      vehicles(id)
    ''');
    final term = _safeTerm(search);
    if (term.isNotEmpty) {
      query = query.or(
        'name.ilike.%$term%,origin.ilike.%$term%,destination.ilike.%$term%',
      );
    }
    final data = await query.order('name');
    return (data as List)
        .whereType<Map>()
        .map((row) => RouteMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<TransportRoute> getRoute(String id) async {
    final data = await _client
        .from('routes')
        .select('''
          id,name,origin,destination,color,active,created_at,
          stops(id,route_id,name,latitude,longitude,stop_order,fare),
          vehicles(id)
        ''')
        .eq('id', id)
        .single();
    return RouteMapper.fromJson(data);
  }

  @override
  Future<String> saveRoute({
    String? id,
    required String name,
    required String origin,
    required String destination,
    required String color,
    required bool active,
  }) async {
    _requireAal2();
    final values = {
      'name': name.trim(),
      'origin': origin.trim(),
      'destination': destination.trim(),
      'color': color.toUpperCase(),
      'active': active,
    };
    if (id == null) {
      final data = await _client
          .from('routes')
          .insert(values)
          .select('id')
          .single();
      return data['id'].toString();
    }
    await _client.from('routes').update(values).eq('id', id);
    return id;
  }

  @override
  Future<void> setRouteActive(String id, bool active) async {
    _requireAal2();
    await _client.from('routes').update({'active': active}).eq('id', id);
  }

  @override
  Future<void> saveStop({
    String? id,
    required String routeId,
    required String name,
    required double latitude,
    required double longitude,
    required int order,
    required double fare,
  }) async {
    _requireAal2();
    final values = {
      'route_id': routeId,
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'stop_order': order,
      'fare': fare,
    };
    if (id == null) {
      await _client.from('stops').insert(values);
    } else {
      await _client.from('stops').update(values).eq('id', id);
    }
  }

  @override
  Future<void> reorderStops(List<RouteStop> stops) async {
    _requireAal2();
    if (stops.isEmpty) return;
    final routeId = stops.first.routeId;
    if (stops.any((stop) => stop.routeId != routeId)) {
      throw const AppException(
        'Todas las paradas deben pertenecer a la misma ruta.',
      );
    }
    await _atomicRpc('reorder_route_stops', {
      'p_route_id': routeId,
      'p_stop_ids': [for (final stop in stops) stop.id],
    });
  }

  @override
  Future<void> deleteStop(String id) async {
    _requireAal2();
    await _client.from('stops').delete().eq('id', id);
  }

  @override
  Future<PagedResult<Driver>> getDrivers({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
  }) async {
    dynamic query = _client.from('drivers').select('''
      id,profile_id,license_number,status,created_at,
      profiles!inner(full_name,email),
      vehicles(id,code,routes(name),vehicle_locations(updated_at))
    ''');
    final term = _safeTerm(search);
    if (term.isNotEmpty) {
      query = query.ilike('profiles.full_name', '%$term%');
    }
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count();
    final items = (response.data as List)
        .whereType<Map>()
        .map((row) => DriverMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return PagedResult(
      items: items,
      total: response.count,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> updateDriver({
    required String id,
    String? licenseNumber,
    required String status,
  }) async {
    _requireAal2();
    await _client
        .from('drivers')
        .update({'license_number': licenseNumber?.trim(), 'status': status})
        .eq('id', id);
  }

  @override
  Future<void> assignDriverVehicle(String driverId, String? vehicleId) async {
    _requireAal2();
    await _atomicRpc('assign_driver_to_vehicle', {
      'p_driver_id': driverId,
      'p_vehicle_id': vehicleId,
    });
  }

  @override
  Future<String> inviteDriver({
    required String email,
    required String fullName,
    String? licenseNumber,
  }) async {
    _requireAal2();
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'invite-driver',
        body: {
          'email': email.trim(),
          'full_name': fullName.trim(),
          'license_number': licenseNumber?.trim(),
        },
      );
    } on FunctionException catch (error) {
      if (error.status == 404 || error.status == 503) {
        throw const AppException(
          'La invitación no está disponible. Verifica el despliegue de invite-driver.',
        );
      }
      if (error.status == 500 &&
          error.details is Map &&
          (error.details as Map)['message']?.toString().contains(
                'DRIVER_INVITE_REDIRECT_URL',
              ) ==
              true) {
        throw const AppException(
          'Falta configurar la redirección real de Traut Conductor para invitar.',
        );
      }
      if (error.status == 403) {
        throw const AppException(
          'Confirma tus permisos de administrador y MFA antes de invitar.',
        );
      }
      if (error.status == 409) {
        throw const AppException(
          'El correo ya tiene una cuenta o invitación; revisa su estado antes de reintentar.',
        );
      }
      throw const AppException('No fue posible invitar al conductor.');
    }
    return response.data is Map
        ? (response.data as Map)['message']?.toString() ??
              'Invitación enviada al conductor.'
        : 'Invitación enviada al conductor.';
  }

  @override
  Future<PagedResult<Incident>> getIncidents({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    dynamic query = _client.from('incidents').select('''
        id,vehicle_id,driver_id,type,description,status,created_at,
        updated_at,resolved_at,resolution_notes,
        vehicles(code),drivers(profiles(full_name))
      ''');
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count();
    final items = (response.data as List)
        .whereType<Map>()
        .map((row) => IncidentMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return PagedResult(
      items: items,
      total: response.count,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> updateIncident({
    required String id,
    required String status,
    String? resolutionNotes,
  }) async {
    _requireAal2();
    final values = <String, Object?>{
      'status': status,
      'resolution_notes': resolutionNotes?.trim(),
    };
    await _client.from('incidents').update(values).eq('id', id);
  }

  @override
  Future<PagedResult<Trip>> getTrips({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    dynamic query = _client.from('trips').select('''
      id,status,started_at,ended_at,created_at,
      vehicles(code),routes(name),drivers(profiles(full_name))
    ''');
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count();
    final items = (response.data as List)
        .whereType<Map>()
        .map((row) => TripMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return PagedResult(
      items: items,
      total: response.count,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> updateTripStatus(String id, String status) async {
    _requireAal2();
    await _client.from('trips').update({'status': status}).eq('id', id);
  }

  Future<void> _atomicRpc(String function, Map<String, Object?> params) async {
    try {
      await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') {
        throw AppException(
          'La operación atómica aún no está instalada en Supabase. Revisa la propuesta SQL 006.',
          code: error.code,
          cause: error,
        );
      }
      if (error.code == '23505') {
        throw AppException(
          'La asignación entra en conflicto con otra operación reciente.',
          code: error.code,
          cause: error,
        );
      }
      if (error.code == '42501') {
        throw AppException(
          'La operación requiere permisos administrativos y MFA vigente.',
          code: error.code,
          cause: error,
        );
      }
      throw AppException(
        'No fue posible completar la operación atómica.',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<List<GlobalSearchResult>> search(String query) async {
    final term = _safeTerm(query);
    if (term.length < 2) return const [];
    final results = <GlobalSearchResult>[];
    final responses = await Future.wait([
      _client
          .from('vehicles')
          .select('id,code,plate')
          .or('code.ilike.%$term%,plate.ilike.%$term%')
          .limit(8),
      _client
          .from('routes')
          .select('id,name,origin,destination')
          .or(
            'name.ilike.%$term%,origin.ilike.%$term%,destination.ilike.%$term%',
          )
          .limit(8),
      _client
          .from('drivers')
          .select('id,profiles!inner(full_name,email)')
          .ilike('profiles.full_name', '%$term%')
          .limit(8),
    ]);
    for (final row in responses[0].whereType<Map>()) {
      results.add(
        GlobalSearchResult(
          id: row['id'].toString(),
          title: row['code'].toString(),
          subtitle: 'Placa ${row['plate']}',
          type: 'Unidad',
          location: '/fleet',
        ),
      );
    }
    for (final row in responses[1].whereType<Map>()) {
      results.add(
        GlobalSearchResult(
          id: row['id'].toString(),
          title: row['name'].toString(),
          subtitle: '${row['origin']} → ${row['destination']}',
          type: 'Ruta',
          location: '/routes/${row['id']}',
        ),
      );
    }
    for (final row in responses[2].whereType<Map>()) {
      final profile = row['profiles'] as Map?;
      results.add(
        GlobalSearchResult(
          id: row['id'].toString(),
          title: profile?['full_name']?.toString() ?? 'Conductor',
          subtitle: profile?['email']?.toString() ?? '',
          type: 'Conductor',
          location: '/drivers',
        ),
      );
    }
    return results;
  }
}
