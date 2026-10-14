import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
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
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

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
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AdminProfile?> currentAdmin() async {
    final user = _client.auth.currentUser;
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
    if (factors.totp.isEmpty) {
      return MfaGate(
        forceEnrollment ? MfaRequirement.enrollment : MfaRequirement.none,
      );
    }
    if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
      return MfaGate(MfaRequirement.challenge, factorId: factors.totp.first.id);
    }
    return const MfaGate(MfaRequirement.none);
  }

  @override
  Future<MfaEnrollment> enrollMfa() async {
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
    String sortBy = 'code',
    bool ascending = true,
  }) async {
    dynamic query = _client.from('vehicles').select(_vehicleSelect).count();
    final term = _safeTerm(search);
    if (term.isNotEmpty) {
      query = query.or('code.ilike.%$term%,plate.ilike.%$term%');
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    final safeSort = const {'code', 'plate', 'created_at'}.contains(sortBy)
        ? sortBy
        : 'code';
    final response = await query
        .order(safeSort, ascending: ascending)
        .range(page * pageSize, (page + 1) * pageSize - 1);
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
    final data = await _client
        .from('vehicles')
        .select(_vehicleSelect)
        .inFilter('status', const ['active', 'no_signal', 'maintenance'])
        .order('code');
    return data
        .whereType<Map>()
        .map((row) => VehicleMapper.fromJson(Map<String, dynamic>.from(row)))
        .where((vehicle) => vehicle.location != null)
        .toList();
  }

  @override
  Stream<void> watchLocations() {
    late final StreamController<void> controller;
    late final RealtimeChannel channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('admin-vehicle-locations')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vehicle_locations',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.channelError &&
                  !controller.isClosed) {
                controller.addError(
                  const AppException(
                    'Se perdió la actualización en vivo. Reconectando…',
                  ),
                );
              }
            });
      },
      onCancel: () async {
        await _client.removeChannel(channel);
        await controller.close();
      },
    );
    return controller.stream;
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
    final values = <String, Object?>{
      'code': code.trim().toUpperCase(),
      'plate': plate.trim().toUpperCase(),
      'status': status,
      'route_id': routeId,
      'driver_id': driverId,
    };
    if (driverId != null) {
      dynamic clear = _client
          .from('vehicles')
          .update({'driver_id': null})
          .eq('driver_id', driverId);
      if (id != null) clear = clear.neq('id', id);
      await clear;
    }
    if (id == null) {
      await _client.from('vehicles').insert(values);
    } else {
      await _client.from('vehicles').update(values).eq('id', id);
    }
  }

  @override
  Future<void> updateVehicleStatus(String id, String status) =>
      _client.from('vehicles').update({'status': status}).eq('id', id);

  @override
  Future<void> assignVehicle({
    required String vehicleId,
    String? routeId,
    String? driverId,
  }) => _client
      .from('vehicles')
      .update({'route_id': routeId, 'driver_id': driverId})
      .eq('id', vehicleId);

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
  Future<void> setRouteActive(String id, bool active) =>
      _client.from('routes').update({'active': active}).eq('id', id);

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
    await Future.wait([
      for (var index = 0; index < stops.length; index++)
        _client
            .from('stops')
            .update({'stop_order': index + 1})
            .eq('id', stops[index].id),
    ]);
  }

  @override
  Future<void> deleteStop(String id) =>
      _client.from('stops').delete().eq('id', id);

  @override
  Future<List<Driver>> getDrivers({String search = '', String? status}) async {
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
    final data = await query.order('created_at', ascending: false).limit(200);
    return (data as List)
        .whereType<Map>()
        .map((row) => DriverMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> updateDriver({
    required String id,
    String? licenseNumber,
    required String status,
  }) => _client
      .from('drivers')
      .update({'license_number': licenseNumber?.trim(), 'status': status})
      .eq('id', id);

  @override
  Future<void> assignDriverVehicle(String driverId, String? vehicleId) async {
    await _client
        .from('vehicles')
        .update({'driver_id': null})
        .eq('driver_id', driverId);
    if (vehicleId != null) {
      await _client
          .from('vehicles')
          .update({'driver_id': driverId})
          .eq('id', vehicleId);
    }
  }

  @override
  Future<void> inviteDriver({
    required String email,
    required String fullName,
    String? licenseNumber,
  }) async {
    final response = await _client.functions.invoke(
      'invite-driver',
      body: {
        'email': email.trim(),
        'full_name': fullName.trim(),
        'license_number': licenseNumber?.trim(),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final message = response.data is Map
          ? (response.data as Map)['message']?.toString()
          : null;
      throw AppException(message ?? 'No fue posible invitar al conductor.');
    }
  }

  @override
  Future<List<Incident>> getIncidents({String? status}) async {
    dynamic query = _client.from('incidents').select('''
        id,vehicle_id,driver_id,type,description,status,created_at,
        updated_at,resolved_at,resolution_notes,
        vehicles(code),drivers(profiles(full_name))
      ''');
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    List<dynamic> data;
    try {
      data = await query.order('created_at', ascending: false).limit(200);
    } on PostgrestException catch (error) {
      if (!error.message.contains('updated_at') &&
          !error.message.contains('resolution_notes') &&
          !error.message.contains('resolved_at')) {
        rethrow;
      }
      dynamic fallback = _client.from('incidents').select('''
          id,vehicle_id,driver_id,type,description,status,created_at,
          vehicles(code),drivers(profiles(full_name))
        ''');
      if (status != null && status.isNotEmpty) {
        fallback = fallback.eq('status', status);
      }
      data = await fallback.order('created_at', ascending: false).limit(200);
    }
    return data
        .whereType<Map>()
        .map((row) => IncidentMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> updateIncident({
    required String id,
    required String status,
    String? resolutionNotes,
  }) async {
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'resolution_notes': resolutionNotes?.trim(),
      'resolved_at': status == 'resolved'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    };
    try {
      await _client.from('incidents').update(values).eq('id', id);
    } on PostgrestException catch (error) {
      if (!error.message.contains('updated_at') &&
          !error.message.contains('resolution_notes') &&
          !error.message.contains('resolved_at')) {
        rethrow;
      }
      await _client.from('incidents').update({'status': status}).eq('id', id);
    }
  }

  @override
  Future<List<Trip>> getTrips({String? status}) async {
    dynamic query = _client.from('trips').select('''
      id,status,started_at,ended_at,created_at,
      vehicles(code),routes(name),drivers(profiles(full_name))
    ''');
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    final data = await query.order('created_at', ascending: false).limit(200);
    return (data as List)
        .whereType<Map>()
        .map((row) => TripMapper.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> updateTripStatus(String id, String status) => _client
      .from('trips')
      .update({
        'status': status,
        if (status == 'finished')
          'ended_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);

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
