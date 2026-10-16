class DashboardMetrics {
  const DashboardMetrics({
    required this.totalVehicles,
    required this.activeVehicles,
    required this.maintenanceVehicles,
    required this.noSignalVehicles,
    required this.activeRoutes,
    required this.activeDrivers,
    required this.activeTrips,
    required this.openIncidents,
  });

  final int totalVehicles;
  final int activeVehicles;
  final int maintenanceVehicles;
  final int noSignalVehicles;
  final int activeRoutes;
  final int activeDrivers;
  final int activeTrips;
  final int openIncidents;
}

class VehicleLocation {
  const VehicleLocation({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final DateTime updatedAt;
}

enum VehicleSignalState {
  recent,
  delayed,
  noSignal,
  recoveredPendingStatus,
  invalidData,
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.code,
    required this.plate,
    required this.status,
    required this.createdAt,
    this.routeId,
    this.routeName,
    this.driverId,
    this.driverName,
    this.location,
    this.invalidLocationData = false,
  });

  final String id;
  final String code;
  final String plate;
  final String status;
  final DateTime? createdAt;
  final String? routeId;
  final String? routeName;
  final String? driverId;
  final String? driverName;
  final VehicleLocation? location;
  final bool invalidLocationData;

  VehicleSignalState signalState(DateTime now) {
    if (invalidLocationData) return VehicleSignalState.invalidData;
    final point = location;
    if (point == null) return VehicleSignalState.noSignal;
    if (point.updatedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      return VehicleSignalState.invalidData;
    }
    final age = now.difference(point.updatedAt);
    final fresh = age < const Duration(minutes: 2);
    if (status == 'no_signal') {
      return fresh
          ? VehicleSignalState.recoveredPendingStatus
          : VehicleSignalState.noSignal;
    }
    return fresh ? VehicleSignalState.recent : VehicleSignalState.delayed;
  }
}

class RouteStop {
  const RouteStop({
    required this.id,
    required this.routeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
    required this.fare,
  });

  final String id;
  final String routeId;
  final String name;
  final double latitude;
  final double longitude;
  final int order;
  final double fare;
}

class TransportRoute {
  const TransportRoute({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.color,
    required this.active,
    required this.createdAt,
    this.stops = const [],
    this.vehicleCount = 0,
    this.invalidStopCount = 0,
  });

  final String id;
  final String name;
  final String origin;
  final String destination;
  final String color;
  final bool active;
  final DateTime? createdAt;
  final List<RouteStop> stops;
  final int vehicleCount;
  final int invalidStopCount;

  double get maximumFare => stops.fold<double>(
    0,
    (maximum, stop) => stop.fare > maximum ? stop.fare : maximum,
  );
}

class Driver {
  const Driver({
    required this.id,
    required this.profileId,
    required this.fullName,
    required this.email,
    required this.status,
    required this.createdAt,
    this.licenseNumber,
    this.vehicleId,
    this.vehicleCode,
    this.routeName,
    this.lastActivity,
  });

  final String id;
  final String profileId;
  final String fullName;
  final String email;
  final String? licenseNumber;
  final String status;
  final DateTime? createdAt;
  final String? vehicleId;
  final String? vehicleCode;
  final String? routeName;
  final DateTime? lastActivity;
}

class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.description,
    this.vehicleId,
    this.vehicleCode,
    this.driverId,
    this.driverName,
    this.updatedAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  final String id;
  final String type;
  final String? description;
  final String status;
  final DateTime? createdAt;
  final String? vehicleId;
  final String? vehicleCode;
  final String? driverId;
  final String? driverName;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
}

class Trip {
  const Trip({
    required this.id,
    required this.status,
    required this.createdAt,
    this.vehicleCode,
    this.routeName,
    this.driverName,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String status;
  final DateTime? createdAt;
  final String? vehicleCode;
  final String? routeName;
  final String? driverName;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasNext => (page + 1) * pageSize < total;
}

class GlobalSearchResult {
  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.location,
  });

  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String location;
}
