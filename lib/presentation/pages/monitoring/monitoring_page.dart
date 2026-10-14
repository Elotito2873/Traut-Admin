import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transport_entities.dart';
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
  Vehicle? _selected;

  @override
  Widget build(BuildContext context) {
    ref.listen(locationChangesProvider, (_, next) {
      next.whenData((_) => ref.invalidate(monitoredVehiclesProvider));
    });
    final asyncVehicles = ref.watch(monitoredVehiclesProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            title: 'Monitoreo GPS',
            subtitle:
                'Ubicación y estado de las unidades con actualización en vivo.',
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
                final filtered = vehicles.where((vehicle) {
                  return (_status == null || vehicle.status == _status) &&
                      (_route == null || vehicle.routeName == _route) &&
                      (_driver == null || vehicle.driverName == _driver);
                }).toList();
                return Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String?>(
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
                            onChanged: (value) =>
                                setState(() => _status = value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _route,
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
                            onChanged: (value) =>
                                setState(() => _route = value),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _driver,
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
                            onChanged: (value) =>
                                setState(() => _driver = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showPanel = constraints.maxWidth >= 820;
                          return Row(
                            children: [
                              Expanded(
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: TransportMap(
                                    config: ref.watch(appConfigProvider),
                                    vehicles: filtered,
                                    selectedVehicleId: _selected?.id,
                                    onVehicleSelected: (vehicle) =>
                                        setState(() => _selected = vehicle),
                                  ),
                                ),
                              ),
                              if (showPanel) ...[
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 320,
                                  child: _VehiclePanel(
                                    selected: _selected,
                                    vehicles: filtered,
                                    onSelected: (vehicle) =>
                                        setState(() => _selected = vehicle),
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
}

class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.selected,
    required this.vehicles,
    required this.onSelected,
  });
  final Vehicle? selected;
  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onSelected;

  @override
  Widget build(BuildContext context) {
    final vehicle = selected;
    return Card(
      child: vehicle == null
          ? ListView(
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
                    subtitle: Text(item.routeName ?? 'Sin ruta'),
                    trailing: StatusBadge(status: item.status),
                    onTap: () => onSelected(item),
                  ),
              ],
            )
          : Padding(
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
                    value:
                        '${vehicle.location?.speed.toStringAsFixed(1) ?? '0'} km/h',
                  ),
                  _Detail(
                    label: 'Última señal',
                    value: vehicle.location == null
                        ? 'Sin información'
                        : DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(vehicle.location!.updatedAt.toLocal()),
                  ),
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
