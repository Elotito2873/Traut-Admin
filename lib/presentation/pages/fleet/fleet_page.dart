import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/validators.dart';
import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/paged_entity_picker.dart';

class FleetPage extends ConsumerStatefulWidget {
  const FleetPage({super.key});

  @override
  ConsumerState<FleetPage> createState() => _FleetPageState();
}

class _FleetPageState extends ConsumerState<FleetPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _status;
  int _page = 0;
  int _pageSize = 25;
  String _sortBy = 'code';
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    ref.read(preferencesProvider).loadTablePageSize().then((value) {
      if (mounted) setState(() => _pageSize = value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  VehicleQuery get _query => VehicleQuery(
    page: _page,
    pageSize: _pageSize,
    search: _search,
    status: _status,
    sortBy: _sortBy,
    ascending: _ascending,
  );

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _search = value;
          _page = 0;
        });
      }
    });
  }

  void _refresh() {
    ref.invalidate(vehiclesProvider);
    ref.invalidate(monitoredVehiclesProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider(_query));
    return Padding(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            title: 'Flota',
            subtitle: 'Administra unidades, asignaciones y estados operativos.',
            actions: [
              FilledButton.icon(
                onPressed: () => _openVehicleDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva unidad'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: responsiveFieldWidth(context, 330),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por código o placa',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'active', child: Text('Activo')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactivo'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Mantenimiento'),
                    ),
                    DropdownMenuItem(
                      value: 'no_signal',
                      child: Text('Sin señal'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 0;
                  }),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _sortBy,
                  decoration: const InputDecoration(labelText: 'Ordenar por'),
                  items: const [
                    DropdownMenuItem(value: 'code', child: Text('Código')),
                    DropdownMenuItem(value: 'plate', child: Text('Placa')),
                    DropdownMenuItem(
                      value: 'created_at',
                      child: Text('Fecha de alta'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _sortBy = value!;
                    _page = 0;
                  }),
                ),
              ),
              IconButton.outlined(
                tooltip: _ascending ? 'Orden ascendente' : 'Orden descendente',
                onPressed: () => setState(() {
                  _ascending = !_ascending;
                  _page = 0;
                }),
                icon: Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Actualizar tabla',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: vehicles.when(
                loading: () => const LoadingPanel(),
                error: (error, _) =>
                    ErrorPanel(error: error, onRetry: _refresh),
                data: (result) {
                  if (result.items.isEmpty) {
                    return const EmptyPanel(
                      message: 'No hay unidades que coincidan con los filtros.',
                      icon: Icons.directions_bus_outlined,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              constraints.maxWidth < 900
                              ? ListView.builder(
                                  itemCount: result.items.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = result.items[index];
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${vehicle.code} · ${vehicle.plate}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                ),
                                                _VehicleActions(
                                                  vehicle: vehicle,
                                                  onEdit: () =>
                                                      _openVehicleDialog(
                                                        vehicle,
                                                      ),
                                                  onStatus: _changeStatus,
                                                ),
                                              ],
                                            ),
                                            StatusBadge(status: vehicle.status),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Ruta: ${vehicle.routeName ?? 'Sin asignar'}',
                                            ),
                                            Text(
                                              'Conductor: ${vehicle.driverName ?? 'Sin asignar'}',
                                            ),
                                            Text(
                                              vehicle.location == null
                                                  ? 'Sin señal registrada'
                                                  : 'Última señal: ${DateFormat('dd/MM/yyyy HH:mm').format(vehicle.location!.updatedAt.toLocal())}',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Código')),
                                        DataColumn(label: Text('Placa')),
                                        DataColumn(label: Text('Ruta')),
                                        DataColumn(label: Text('Conductor')),
                                        DataColumn(label: Text('Estado')),
                                        DataColumn(label: Text('Última señal')),
                                        DataColumn(label: Text('Acciones')),
                                      ],
                                      rows: [
                                        for (final vehicle in result.items)
                                          DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  vehicle.code,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(vehicle.plate)),
                                              DataCell(
                                                Text(
                                                  vehicle.routeName ??
                                                      'Sin asignar',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  vehicle.driverName ??
                                                      'Sin asignar',
                                                ),
                                              ),
                                              DataCell(
                                                StatusBadge(
                                                  status: vehicle.status,
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  vehicle.location == null
                                                      ? 'Sin señal registrada'
                                                      : DateFormat(
                                                          'dd/MM/yyyy HH:mm',
                                                        ).format(
                                                          vehicle
                                                              .location!
                                                              .updatedAt
                                                              .toLocal(),
                                                        ),
                                                ),
                                              ),
                                              DataCell(
                                                _VehicleActions(
                                                  vehicle: vehicle,
                                                  onEdit: () =>
                                                      _openVehicleDialog(
                                                        vehicle,
                                                      ),
                                                  onStatus: _changeStatus,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      PagedTableFooter<Vehicle>(
                        result: result,
                        onPageSize: (value) {
                          setState(() {
                            _pageSize = value;
                            _page = 0;
                          });
                          ref
                              .read(preferencesProvider)
                              .saveTablePageSize(value);
                        },
                        onPage: (value) => setState(() => _page = value),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVehicleDialog([Vehicle? vehicle]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VehicleFormDialog(vehicle: vehicle),
    );
    if (saved == true) _refresh();
  }

  Future<void> _changeStatus(Vehicle vehicle, String status) async {
    final labels = {
      'maintenance': 'poner en mantenimiento',
      'inactive': 'desactivar',
      'active': 'activar',
      'no_signal': 'marcar sin señal',
    };
    final confirmed = await confirmAction(
      context,
      title: 'Cambiar estado de ${vehicle.code}',
      message:
          '¿Deseas ${labels[status] ?? 'cambiar el estado de'} esta unidad? El cambio será visible para el resto del sistema.',
      confirmLabel: 'Sí, continuar',
      destructive: status == 'inactive',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(changeVehicleStatusUseCaseProvider)
          .call(vehicle.id, status);
      if (!mounted) return;
      showOperationSuccess(context, 'Estado actualizado.');
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }
}

class _VehicleActions extends StatelessWidget {
  const _VehicleActions({
    required this.vehicle,
    required this.onEdit,
    required this.onStatus,
  });
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final Future<void> Function(Vehicle, String) onStatus;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Acciones de ${vehicle.code}',
    onSelected: (value) {
      if (value == 'edit') {
        onEdit();
      } else {
        onStatus(vehicle, value);
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(value: 'edit', child: Text('Editar y asignar')),
      if (vehicle.status != 'active')
        const PopupMenuItem(value: 'active', child: Text('Activar')),
      if (vehicle.status != 'maintenance')
        const PopupMenuItem(
          value: 'maintenance',
          child: Text('Poner en mantenimiento'),
        ),
      if (vehicle.status != 'inactive')
        const PopupMenuItem(value: 'inactive', child: Text('Desactivar')),
    ],
  );
}

class VehicleFormDialog extends ConsumerStatefulWidget {
  const VehicleFormDialog({super.key, this.vehicle});
  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _plate;
  late String _status;
  String? _routeId;
  String? _driverId;
  String? _driverName;
  bool _saving = false;
  late final Future<List<TransportRoute>> _routes;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.vehicle?.code);
    _plate = TextEditingController(text: widget.vehicle?.plate);
    _status = widget.vehicle?.status ?? 'active';
    _routeId = widget.vehicle?.routeId;
    _driverId = widget.vehicle?.driverId;
    _driverName = widget.vehicle?.driverName;
    _routes = ref.read(routeRepositoryProvider).getRoutes();
  }

  @override
  void dispose() {
    _code.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Nueva unidad' : 'Editar unidad'),
      content: SizedBox(
        width: responsiveDialogWidth(context, 560),
        child: FutureBuilder<List<TransportRoute>>(
          future: _routes,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 240,
                child: ErrorPanel(
                  error: snapshot.error!,
                  onRetry: () => Navigator.pop(context, false),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(height: 240, child: LoadingPanel());
            }
            final routes = snapshot.data!;
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _code,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Código'),
                      validator: (value) =>
                          Validators.requiredText(value, 'El código'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _plate,
                      decoration: const InputDecoration(labelText: 'Placa'),
                      validator: (value) =>
                          Validators.requiredText(value, 'La placa'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Activo'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactivo'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Mantenimiento'),
                        ),
                        DropdownMenuItem(
                          value: 'no_signal',
                          child: Text('Sin señal'),
                        ),
                      ],
                      onChanged: (value) => _status = value!,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _routeId,
                      decoration: const InputDecoration(
                        labelText: 'Ruta asignada',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sin ruta'),
                        ),
                        for (final route in routes)
                          DropdownMenuItem(
                            value: route.id,
                            child: Text(route.name),
                          ),
                      ],
                      onChanged: (value) => _routeId = value,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _driverName ?? 'Sin conductor asignado',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final driver = await showPagedEntityPicker<Driver>(
                              context,
                              title: 'Buscar conductor activo',
                              load: (page, query) => ref
                                  .read(driverRepositoryProvider)
                                  .getDrivers(
                                    page: page,
                                    pageSize: 20,
                                    search: query,
                                    status: 'active',
                                  ),
                              label: (driver) => driver.fullName,
                            );
                            if (driver != null && mounted) {
                              setState(() {
                                _driverId = driver.id;
                                _driverName = driver.fullName;
                              });
                            }
                          },
                          child: const Text('Buscar'),
                        ),
                        if (_driverId != null)
                          IconButton(
                            tooltip: 'Quitar conductor',
                            onPressed: () => setState(() {
                              _driverId = null;
                              _driverName = null;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .saveVehicle(
            id: widget.vehicle?.id,
            code: _code.text,
            plate: _plate.text,
            status: _status,
            routeId: _routeId,
            driverId: _driverId,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showOperationError(context, error);
      }
    }
  }
}
