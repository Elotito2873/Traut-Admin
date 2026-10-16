import '../../domain/entities/admin_profile.dart';
import '../../domain/entities/transport_entities.dart';

Map<String, dynamic>? _relation(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty) return _relation(value.first);
  return null;
}

List<Map<String, dynamic>> _relations(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');

double? _coordinate(Object? value, double limit) {
  final number = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
  if (number == null || !number.isFinite || number.abs() > limit) return null;
  return number;
}

double _number(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? 0,
  _ => 0,
};

class ProfileMapper {
  const ProfileMapper._();

  static AdminProfile fromJson(Map<String, dynamic> json) => AdminProfile(
    id: json['id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? 'Administrador',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    avatarPreset: json['avatar_preset']?.toString(),
  );
}

class VehicleMapper {
  const VehicleMapper._();

  static Vehicle fromJson(Map<String, dynamic> json) {
    final route = _relation(json['routes']);
    final driver = _relation(json['drivers']);
    final profile = _relation(driver?['profiles']);
    final location = _relation(json['vehicle_locations']);
    final latitude = _coordinate(location?['latitude'], 90);
    final longitude = _coordinate(location?['longitude'], 180);
    final updatedAt = _date(location?['updated_at']);
    final validLocation =
        location != null &&
        latitude != null &&
        longitude != null &&
        updatedAt != null;
    return Vehicle(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      plate: json['plate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'inactive',
      createdAt: _date(json['created_at']),
      routeId: json['route_id']?.toString(),
      routeName: route?['name']?.toString(),
      driverId: json['driver_id']?.toString(),
      driverName: profile?['full_name']?.toString(),
      invalidLocationData: location != null && !validLocation,
      location: !validLocation
          ? null
          : VehicleLocation(
              latitude: latitude,
              longitude: longitude,
              speed: _number(location['speed']),
              heading: _number(location['heading']),
              updatedAt: updatedAt,
            ),
    );
  }
}

class StopMapper {
  const StopMapper._();

  static RouteStop? fromJson(Map<String, dynamic> json) {
    final latitude = _coordinate(json['latitude'], 90);
    final longitude = _coordinate(json['longitude'], 180);
    if (latitude == null || longitude == null) return null;
    return RouteStop(
      id: json['id']?.toString() ?? '',
      routeId: json['route_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      order: (json['stop_order'] as num?)?.toInt() ?? 0,
      fare: _number(json['fare']),
    );
  }
}

class RouteMapper {
  const RouteMapper._();

  static TransportRoute fromJson(Map<String, dynamic> json) {
    final rawStops = _relations(json['stops']);
    final stops =
        rawStops.map(StopMapper.fromJson).whereType<RouteStop>().toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return TransportRoute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      color: json['color']?.toString() ?? '#4F46E5',
      active: json['active'] == true,
      createdAt: _date(json['created_at']),
      stops: stops,
      vehicleCount: _relations(json['vehicles']).length,
      invalidStopCount: rawStops.length - stops.length,
    );
  }
}

class DriverMapper {
  const DriverMapper._();

  static Driver fromJson(Map<String, dynamic> json) {
    final profile = _relation(json['profiles']);
    final vehicle = _relation(json['vehicles']);
    final route = _relation(vehicle?['routes']);
    final location = _relation(vehicle?['vehicle_locations']);
    return Driver(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      fullName: profile?['full_name']?.toString() ?? 'Sin nombre',
      email: profile?['email']?.toString() ?? '',
      licenseNumber: json['license_number']?.toString(),
      status: json['status']?.toString() ?? 'inactive',
      createdAt: _date(json['created_at']),
      vehicleId: vehicle?['id']?.toString(),
      vehicleCode: vehicle?['code']?.toString(),
      routeName: route?['name']?.toString(),
      lastActivity: location == null ? null : _date(location['updated_at']),
    );
  }
}

class IncidentMapper {
  const IncidentMapper._();

  static Incident fromJson(Map<String, dynamic> json) {
    final vehicle = _relation(json['vehicles']);
    final driver = _relation(json['drivers']);
    final profile = _relation(driver?['profiles']);
    return Incident(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Sin tipo',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'open',
      createdAt: _date(json['created_at']),
      vehicleId: json['vehicle_id']?.toString(),
      vehicleCode: vehicle?['code']?.toString(),
      driverId: json['driver_id']?.toString(),
      driverName: profile?['full_name']?.toString(),
      updatedAt: json['updated_at'] == null ? null : _date(json['updated_at']),
      resolvedAt: json['resolved_at'] == null
          ? null
          : _date(json['resolved_at']),
      resolutionNotes: json['resolution_notes']?.toString(),
    );
  }
}

class TripMapper {
  const TripMapper._();

  static Trip fromJson(Map<String, dynamic> json) {
    final vehicle = _relation(json['vehicles']);
    final route = _relation(json['routes']);
    final driver = _relation(json['drivers']);
    final profile = _relation(driver?['profiles']);
    return Trip(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: _date(json['created_at']),
      vehicleCode: vehicle?['code']?.toString(),
      routeName: route?['name']?.toString(),
      driverName: profile?['full_name']?.toString(),
      startedAt: json['started_at'] == null ? null : _date(json['started_at']),
      endedAt: json['ended_at'] == null ? null : _date(json['ended_at']),
    );
  }
}
