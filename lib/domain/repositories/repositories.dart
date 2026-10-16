import '../entities/admin_profile.dart';
import '../entities/transport_entities.dart';

abstract interface class AuthRepository {
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<AdminProfile?> currentAdmin();
  Future<MfaGate> mfaRequirement({required bool forceEnrollment});
  bool get hasAal2;
  Future<MfaEnrollment> enrollMfa();
  Future<void> verifyMfa({required String factorId, required String code});
  Future<String?> verifiedTotpFactorId();
  Future<void> unenrollMfa(String factorId);
}

enum MfaRequirement { none, challenge, enrollment }

class MfaGate {
  const MfaGate(this.requirement, {this.factorId});

  final MfaRequirement requirement;
  final String? factorId;
}

class MfaEnrollment {
  const MfaEnrollment({
    required this.factorId,
    required this.qrCode,
    required this.secret,
  });

  final String factorId;
  final String qrCode;
  final String secret;
}

abstract interface class DashboardRepository {
  Future<DashboardMetrics> getMetrics();
}

enum RealtimeConnectionStatus {
  reconnecting,
  connected,
  timeout,
  error,
  closed,
}

class LocationMonitorEvent {
  const LocationMonitorEvent({
    this.ids = const {},
    this.status = RealtimeConnectionStatus.reconnecting,
    this.refreshAll = false,
  });

  final Set<String> ids;
  final RealtimeConnectionStatus status;
  final bool refreshAll;
}

abstract interface class VehicleRepository {
  Future<PagedResult<Vehicle>> getVehicles({
    required int page,
    required int pageSize,
    String search,
    String? status,
    String? availableForDriverId,
    String sortBy = 'code',
    bool ascending = true,
  });
  Future<List<Vehicle>> getMonitoredVehicles();
  Future<List<Vehicle>> getMonitoredVehiclesByIds(Set<String> ids);
  Stream<LocationMonitorEvent> watchLocations();
  Future<int> markStaleVehiclesNoSignal();
  Future<void> saveVehicle({
    String? id,
    required String code,
    required String plate,
    required String status,
    String? routeId,
    String? driverId,
  });
  Future<void> updateVehicleStatus(String id, String status);
}

abstract interface class RouteRepository {
  Future<List<TransportRoute>> getRoutes({String search = ''});
  Future<TransportRoute> getRoute(String id);
  Future<String> saveRoute({
    String? id,
    required String name,
    required String origin,
    required String destination,
    required String color,
    required bool active,
  });
  Future<void> setRouteActive(String id, bool active);
  Future<void> saveStop({
    String? id,
    required String routeId,
    required String name,
    required double latitude,
    required double longitude,
    required int order,
    required double fare,
  });
  Future<void> reorderStops(List<RouteStop> stops);
  Future<void> deleteStop(String id);
}

abstract interface class DriverRepository {
  Future<PagedResult<Driver>> getDrivers({
    required int page,
    required int pageSize,
    String search = '',
    String? status,
  });
  Future<void> updateDriver({
    required String id,
    String? licenseNumber,
    required String status,
  });
  Future<void> assignDriverVehicle(String driverId, String? vehicleId);
  Future<String> inviteDriver({
    required String email,
    required String fullName,
    String? licenseNumber,
  });
}

abstract interface class IncidentRepository {
  Future<PagedResult<Incident>> getIncidents({
    required int page,
    required int pageSize,
    String? status,
  });
  Future<void> updateIncident({
    required String id,
    required String status,
    String? resolutionNotes,
  });
}

abstract interface class TripRepository {
  Future<PagedResult<Trip>> getTrips({
    required int page,
    required int pageSize,
    String? status,
  });
  Future<void> updateTripStatus(String id, String status);
}

abstract interface class SearchRepository {
  Future<List<GlobalSearchResult>> search(String query);
}
