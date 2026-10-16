import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/entities/transport_entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/transport_map.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({super.key});

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage> {
  String? _status;
  String? _route;
  String? _driver;
  String? _selectedId;
  final _mapController = MapController();
  bool _checkingSignal = false;
  final ValueNotifier<DateTime> _clock = ValueNotifier(DateTime.now());
  late final Timer _freshnessTimer;

  @override
  void initState() {
    super.initState();
    _freshnessTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _clock.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _freshnessTimer.cancel();
    _clock.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationChangesProvider, (_, next) {
      next.whenData((event) {
        final notifier = ref.read(monitoredVehiclesProvider.notifier);
        if (event.refreshAll) {
          notifier.refreshAll();
        } else if (event.ids.isNotEmpty) {
          notifier.refreshIds(event.ids);
        }
      });
    });
    final realtime = ref.watch(locationChangesProvider);
    final asyncVehicles = ref.watch(monitoredVehiclesProvider);
    return Padding(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            title: 'Monitoreo GPS',
            subtitle:
                'Ubicación y estado de las unidades con actualización en vivo.',
            actions: [
              OutlinedButton.icon(
                onPressed: _checkingSignal ? null : _checkStaleSignal,
                icon: const Icon(Icons.wifi_find),
                label: Text(
                  _checkingSignal ? 'Revisando…' : 'Revisar sin señal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncVehicles.when(
              loading: () => const LoadingPanel(),
              error: (error, _) => ErrorPanel(
                error: error,
                onRetry: () => ref.invalidate(monitoredVehiclesProvider),
              ),
              data: (vehicles) {
                final refreshError = ref
                    .read(monitoredVehiclesProvider.notifier)
                    .lastRefreshError;
                final routeNames =
                    vehicles
                        .map((item) => item.routeName)
                        .whereType<String>()
                        .toSet()
                        .toList()
                      ..sort();
                final driverNames =
                    vehicles
                        .map((item) => item.driverName)
                        .whereType<String>()
                        .toSet()
                        .toList()
                      ..sort();
                final routeFilter = routeNames.contains(_route) ? _route : null;
                final driverFilter = driverNames.contains(_driver)
                    ? _driver
                    : null;
                final filtered = vehicles.where((vehicle) {
                  return (_status == null || vehicle.status == _status) &&
                      (routeFilter == null ||
                          vehicle.routeName == routeFilter) &&
                      (driverFilter == null ||
                          vehicle.driverName == driverFilter);
                }).toList();
                Vehicle? selected;
                for (final vehicle in filtered) {
                  if (vehicle.id == _selectedId) {
                    selected = vehicle;
                    break;
                  }
                }
                if (_selectedId != null && selected == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedId != null) {
                      setState(() => _selectedId = null);
                    }
                  });
                }
                return Column(
                  children: [
                    _RealtimeStatus(
                      status:
                          realtime.value?.status ??
                          RealtimeConnectionStatus.reconnecting,
                      refreshError: refreshError,
                      onRetry: () {
                        ref.invalidate(locationChangesProvider);
                        ref
                            .read(monitoredVehiclesProvider.notifier)
                            .refreshAll();
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Activas'),
                              ),
                              DropdownMenuItem(
                                value: 'no_signal',
                                child: Text('Sin señal'),
                              ),
                              DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Mantenimiento'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _status = value;
                              _selectedId = null;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            key: ValueKey(routeFilter),
                            initialValue: routeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Ruta',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todas'),
                              ),
                              for (final route in routeNames)
                                DropdownMenuItem(
                                  value: route,
                                  child: Text(route),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _route = value;
                              _selectedId = null;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            key: ValueKey(driverFilter),
                            initialValue: driverFilter,
                            decoration: const InputDecoration(
                              labelText: 'Conductor',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
                              ),
                              for (final driver in driverNames)
                                DropdownMenuItem(
                                  value: driver,
                                  child: Text(driver),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _driver = value;
                              _selectedId = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (MediaQuery.sizeOf(context).width < 820) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showVehicleList(filtered),
                          icon: const Icon(Icons.list),
                          label: Text(
                            'Ver ${filtered.length} unidades, incluso sin GPS',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showPanel = constraints.maxWidth >= 820;
                          void select(Vehicle vehicle) {
                            _selectVehicle(vehicle);
                            if (!showPanel) _showVehicleDetails(vehicle);
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: TransportMap(
                                    config: ref.watch(appConfigProvider),
                                    vehicles: filtered,
                                    mapController: _mapController,
                                    selectedVehicleId: selected?.id,
                                    onVehicleSelected: select,
                                  ),
                                ),
                              ),
                              if (showPanel) ...[
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 320,
                                  child: _VehiclePanel(
                                    selected: selected,
                                    vehicles: filtered,
                                    onSelected: select,
                                    now: _clock,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectVehicle(Vehicle vehicle) {
    setState(() => _selectedId = vehicle.id);
    final location = vehicle.location;
    if (location != null) {
      _mapController.move(LatLng(location.latitude, location.longitude), 16);
    }
  }

  Future<void> _checkStaleSignal() async {
    final confirmed = await confirmAction(
      context,
      title: 'Revisión manual de señal',
      message:
          'Se marcarán sin señal las unidades activas cuyo último GPS supere cinco minutos. No existe una detección automática programada.',
      confirmLabel: 'Revisar ahora',
    );
    if (!confirmed || !mounted) return;
    setState(() => _checkingSignal = true);
    try {
      final count = await ref
          .read(vehicleRepositoryProvider)
          .markStaleVehiclesNoSignal();
      if (!mounted) return;
      final refreshed = await ref
          .read(monitoredVehiclesProvider.notifier)
          .refreshAll();
      ref.invalidate(dashboardProvider);
      if (mounted) {
        showOperationSuccess(
          context,
          refreshed
              ? '$count unidades marcadas sin señal.'
              : '$count unidades marcadas. La vista no pudo actualizarse; reintenta.',
        );
      }
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _checkingSignal = false);
    }
  }

  Future<void> _showVehicleDetails(Vehicle vehicle) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 390,
          child: _VehiclePanel(
            selected: vehicle,
            vehicles: const [],
            onSelected: (_) {},
            now: _clock,
          ),
        ),
      ),
    );
  }

  Future<void> _showVehicleList(List<Vehicle> vehicles) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.65,
            child: _VehiclePanel(
              selected: null,
              vehicles: vehicles,
              now: _clock,
              onSelected: (vehicle) {
                Navigator.pop(sheetContext);
                _selectVehicle(vehicle);
                _showVehicleDetails(vehicle);
              },
            ),
          ),
        ),
      );
}

class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.selected,
    required this.vehicles,
    required this.onSelected,
    required this.now,
  });
  final Vehicle? selected;
  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onSelected;
  final ValueListenable<DateTime> now;

  @override
  Widget build(BuildContext context) {
    final vehicle = selected;
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, currentTime, _) => Card(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: vehicle == null
              ? ListView(
                  key: const ValueKey('vehicle-list'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      '${vehicles.length} unidades visibles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final item in vehicles)
                      ListTile(
                        minTileHeight: 58,
                        leading: const Icon(Icons.directions_bus),
                        title: Text(item.code),
                        subtitle: Text(
                          '${item.routeName ?? 'Sin ruta'} · ${_signalLabel(item.signalState(currentTime))}',
                        ),
                        trailing: StatusBadge(status: item.status),
                        onTap: () => onSelected(item),
                      ),
                  ],
                )
              : SingleChildScrollView(
                  child: Padding(
                    key: ValueKey(vehicle.id),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Unidad ${vehicle.code}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(status: vehicle.status),
                        const SizedBox(height: 8),
                        Text(_signalLabel(vehicle.signalState(currentTime))),
                        const Divider(height: 28),
                        _Detail(label: 'Placa', value: vehicle.plate),
                        _Detail(
                          label: 'Ruta',
                          value: vehicle.routeName ?? 'Sin asignar',
                        ),
                        _Detail(
                          label: 'Conductor',
                          value: vehicle.driverName ?? 'Sin asignar',
                        ),
                        _Detail(
                          label: 'Velocidad',
                          value: vehicle.location == null
                              ? 'Sin información'
                              : '${vehicle.location!.speed.toStringAsFixed(1)} km/h',
                        ),
                        _Detail(
                          label: 'Última señal',
                          value: vehicle.location == null
                              ? vehicle.invalidLocationData
                                    ? 'Datos de ubicación inválidos'
                                    : 'Sin información'
                              : DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(vehicle.location!.updatedAt.toLocal()),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

String _signalLabel(VehicleSignalState signal) => switch (signal) {
  VehicleSignalState.recent => 'Señal reciente',
  VehicleSignalState.delayed => 'Señal atrasada',
  VehicleSignalState.noSignal => 'Sin señal',
  VehicleSignalState.recoveredPendingStatus =>
    'Señal recuperada; estado aún sin reactivar',
  VehicleSignalState.invalidData => 'Datos GPS inválidos',
};

class _RealtimeStatus extends StatelessWidget {
  const _RealtimeStatus({
    required this.status,
    this.refreshError,
    required this.onRetry,
  });

  final RealtimeConnectionStatus status;
  final String? refreshError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      RealtimeConnectionStatus.connected => 'En vivo',
      RealtimeConnectionStatus.reconnecting => 'Conectando tiempo real…',
      RealtimeConnectionStatus.timeout => 'Tiempo real agotado; reconectando…',
      RealtimeConnectionStatus.error =>
        'Tiempo real interrumpido; reconectando…',
      RealtimeConnectionStatus.closed => 'Tiempo real desconectado',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: status != RealtimeConnectionStatus.connected,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              status == RealtimeConnectionStatus.connected
                  ? Icons.wifi
                  : Icons.wifi_off,
              size: 16,
              color: status == RealtimeConnectionStatus.connected
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (refreshError != null)
              Text(
                'Actualización pendiente: $refreshError',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (refreshError != null ||
                status == RealtimeConnectionStatus.error ||
                status == RealtimeConnectionStatus.timeout ||
                status == RealtimeConnectionStatus.closed)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
