import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/preferences_service.dart';
import '../../data/repositories/supabase_repositories.dart';
import '../../domain/entities/transport_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/admin_usecases.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig debe configurarse en main.'),
);

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final preferencesProvider = Provider((ref) => PreferencesService());

final adminRepositoryProvider = Provider<SupabaseAdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final verifiedTotpProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(authRepositoryProvider).verifiedTotpFactorId(),
);
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => ref.watch(adminRepositoryProvider),
);

final authorizeAdminUseCaseProvider = Provider(
  (ref) => AuthorizeAdminUseCase(ref.watch(authRepositoryProvider)),
);
final changeVehicleStatusUseCaseProvider = Provider(
  (ref) => ChangeVehicleStatusUseCase(ref.watch(vehicleRepositoryProvider)),
);
final updateIncidentUseCaseProvider = Provider(
  (ref) => UpdateIncidentUseCase(ref.watch(incidentRepositoryProvider)),
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future<void>(() async {
      state = await ref.read(preferencesProvider).loadThemeMode();
    });
    return ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesProvider).saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

// Las consultas de catálogo se conservan durante la sesión administrativa.
// Sus mutaciones y el cierre de sesión las invalidan de forma explícita.
final dashboardProvider = FutureProvider<DashboardMetrics>(
  (ref) => ref.watch(dashboardRepositoryProvider).getMetrics(),
);

class MonitoredVehiclesController extends AsyncNotifier<List<Vehicle>> {
  final Set<String> _pendingIds = {};
  bool _refreshing = false;
  String? lastRefreshError;

  @override
  Future<List<Vehicle>> build() {
    return ref.watch(vehicleRepositoryProvider).getMonitoredVehicles();
  }

  Future<bool> refreshAll() async {
    try {
      final vehicles = await ref
          .read(vehicleRepositoryProvider)
          .getMonitoredVehicles();
      if (!ref.mounted) return false;
      lastRefreshError = null;
      state = AsyncData(vehicles);
      return true;
    } catch (error, stackTrace) {
      if (!ref.mounted) return false;
      lastRefreshError = userFriendlyError(error);
      final previous = state.value;
      state = previous == null
          ? AsyncError<List<Vehicle>>(error, stackTrace)
          : AsyncData(previous);
      return false;
    }
  }

  Future<void> refreshIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    _pendingIds.addAll(ids);
    if (_refreshing) return;
    _refreshing = true;
    try {
      while (_pendingIds.isNotEmpty) {
        final batch = Set<String>.of(_pendingIds);
        _pendingIds.removeAll(batch);
        final current = state.value;
        if (current == null) {
          ref.invalidateSelf();
          return;
        }
        final changed = await ref
            .read(vehicleRepositoryProvider)
            .getMonitoredVehiclesByIds(batch);
        if (!ref.mounted) return;
        final merged = {for (final vehicle in current) vehicle.id: vehicle};
        for (final id in batch) {
          merged.remove(id);
        }
        for (final vehicle in changed) {
          merged[vehicle.id] = vehicle;
        }
        final next = merged.values.toList()
          ..sort((left, right) => left.code.compareTo(right.code));
        lastRefreshError = null;
        state = AsyncData(next);
      }
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      lastRefreshError = userFriendlyError(error);
      final previous = state.value;
      state = previous == null
          ? AsyncError<List<Vehicle>>(error, stackTrace)
          : AsyncData(previous);
    } finally {
      _refreshing = false;
    }
  }
}

final monitoredVehiclesProvider =
    AsyncNotifierProvider<MonitoredVehiclesController, List<Vehicle>>(
      MonitoredVehiclesController.new,
    );

// El canal Realtime solo vive mientras Monitoreo tiene un listener. Así, al
// abandonar la pantalla se cancela el canal y al volver se crea exactamente uno.
final locationChangesProvider =
    StreamProvider.autoDispose<LocationMonitorEvent>(
      (ref) => ref.watch(vehicleRepositoryProvider).watchLocations(),
    );

class VehicleQuery {
  const VehicleQuery({
    this.page = 0,
    this.pageSize = 25,
    this.search = '',
    this.status,
    this.sortBy = 'code',
    this.ascending = true,
  });

  final int page;
  final int pageSize;
  final String search;
  final String? status;
  final String sortBy;
  final bool ascending;

  @override
  bool operator ==(Object other) =>
      other is VehicleQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.search == search &&
      other.status == status &&
      other.sortBy == sortBy &&
      other.ascending == ascending;

  @override
  int get hashCode =>
      Object.hash(page, pageSize, search, status, sortBy, ascending);
}

final vehiclesProvider =
    FutureProvider.family<PagedResult<Vehicle>, VehicleQuery>(
      (ref, query) => ref
          .watch(vehicleRepositoryProvider)
          .getVehicles(
            page: query.page,
            pageSize: query.pageSize,
            search: query.search,
            status: query.status,
            sortBy: query.sortBy,
            ascending: query.ascending,
          ),
    );

final routesProvider = FutureProvider.family<List<TransportRoute>, String>(
  (ref, search) => ref.watch(routeRepositoryProvider).getRoutes(search: search),
);

final routeProvider = FutureProvider.family<TransportRoute, String>(
  (ref, id) => ref.watch(routeRepositoryProvider).getRoute(id),
);

class DriverQuery {
  const DriverQuery({
    this.page = 0,
    this.pageSize = 25,
    this.search = '',
    this.status,
  });
  final int page;
  final int pageSize;
  final String search;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is DriverQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.search == search &&
      other.status == status;
  @override
  int get hashCode => Object.hash(page, pageSize, search, status);
}

final driversProvider = FutureProvider.family<PagedResult<Driver>, DriverQuery>(
  (ref, query) => ref
      .watch(driverRepositoryProvider)
      .getDrivers(
        page: query.page,
        pageSize: query.pageSize,
        search: query.search,
        status: query.status,
      ),
);

class IncidentQuery {
  const IncidentQuery({this.page = 0, this.pageSize = 25, this.status});
  final int page;
  final int pageSize;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is IncidentQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.status == status;
  @override
  int get hashCode => Object.hash(page, pageSize, status);
}

final incidentsProvider =
    FutureProvider.family<PagedResult<Incident>, IncidentQuery>(
      (ref, query) => ref
          .watch(incidentRepositoryProvider)
          .getIncidents(
            page: query.page,
            pageSize: query.pageSize,
            status: query.status,
          ),
    );

class TripQuery {
  const TripQuery({this.page = 0, this.pageSize = 25, this.status});
  final int page;
  final int pageSize;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is TripQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.status == status;
  @override
  int get hashCode => Object.hash(page, pageSize, status);
}

final tripsProvider = FutureProvider.family<PagedResult<Trip>, TripQuery>(
  (ref, query) => ref
      .watch(tripRepositoryProvider)
      .getTrips(
        page: query.page,
        pageSize: query.pageSize,
        status: query.status,
      ),
);
