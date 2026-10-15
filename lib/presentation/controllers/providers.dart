import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
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

final dashboardProvider = FutureProvider<DashboardMetrics>(
  (ref) => ref.watch(dashboardRepositoryProvider).getMetrics(),
);

final monitoredVehiclesProvider = FutureProvider<List<Vehicle>>(
  (ref) => ref.watch(vehicleRepositoryProvider).getMonitoredVehicles(),
);

final locationChangesProvider = StreamProvider.autoDispose<Set<String>>(
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
