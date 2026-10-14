import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/validators.dart';
import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class DriversPage extends ConsumerStatefulWidget {
  const DriversPage({super.key});

  @override
  ConsumerState<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends ConsumerState<DriversPage> {
  Timer? _debounce;
  String _search = '';
  String? _status;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  DriverQuery get _query => DriverQuery(search: _search, status: _status);

  void _refresh() {
    ref.invalidate(driversProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(monitoredVehiclesProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(driversProvider(_query));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            title: 'Conductores',
            subtitle: 'Administra estado, licencia y unidad asignada.',
            actions: [
              FilledButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invitar conductor'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => _search = value);
                    });
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
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
                      value: 'suspended',
                      child: Text('Suspendido'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: drivers.when(
                loading: () => const LoadingPanel(),
                error: (error, _) =>
                    ErrorPanel(error: error, onRetry: _refresh),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyPanel(
                      message: 'No hay conductores para mostrar.',
                      icon: Icons.badge_outlined,
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Licencia')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Unidad')),
                          DataColumn(label: Text('Ruta')),
                          DataColumn(label: Text('Última actividad')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: [
                          for (final driver in items)
                            DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driver.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(driver.email),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(driver.licenseNumber ?? 'Sin registrar'),
                                ),
                                DataCell(StatusBadge(status: driver.status)),
                                DataCell(
                                  Text(driver.vehicleCode ?? 'Sin asignar'),
                                ),
                                DataCell(
                                  Text(driver.routeName ?? 'Sin asignar'),
                                ),
                                DataCell(
                                  Text(
                                    driver.lastActivity == null
                                        ? 'Sin actividad registrada'
                                        : DateFormat('dd/MM/yyyy HH:mm').format(
                                            driver.lastActivity!.toLocal(),
                                          ),
                                  ),
                                ),
                                DataCell(
                                  PopupMenuButton<String>(
                                    tooltip: 'Acciones de ${driver.fullName}',
                                    onSelected: (action) =>
                                        _handleAction(driver, action),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'assign',
                                        child: Text('Asignar unidad'),
                                      ),
                                      if (driver.vehicleId != null)
                                        const PopupMenuItem(
                                          value: 'unassign',
                                          child: Text('Quitar asignación'),
                                        ),
                                      if (driver.status != 'suspended')
                                        const PopupMenuItem(
                                          value: 'suspended',
                                          child: Text('Suspender'),
                                        ),
                                      if (driver.status != 'active')
                                        const PopupMenuItem(
                                          value: 'active',
                                          child: Text('Activar'),
                                        ),
                                    ],
                                  ),
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
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(Driver driver, String action) async {
    if (action == 'edit') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => DriverFormDialog(driver: driver),
      );
      if (saved == true) _refresh();
      return;
    }
    if (action == 'assign') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AssignVehicleDialog(driver: driver),
      );
      if (saved == true) _refresh();
      return;
    }
    if (action == 'unassign') {
      final confirmed = await confirmAction(
        context,
        title: 'Quitar unidad asignada',
        message:
            '${driver.fullName} dejará de tener asignada la unidad ${driver.vehicleCode}.',
        confirmLabel: 'Quitar asignación',
      );
      if (!confirmed || !mounted) return;
      try {
        await ref
            .read(driverRepositoryProvider)
            .assignDriverVehicle(driver.id, null);
        if (!mounted) return;
        showOperationSuccess(context, 'Asignación retirada.');
        _refresh();
      } catch (error) {
        if (mounted) showOperationError(context, error);
      }
      return;
    }
    final suspended = action == 'suspended';
    final confirmed = await confirmAction(
      context,
      title: suspended ? 'Suspender conductor' : 'Activar conductor',
      message: suspended
          ? '${driver.fullName} no deberá operar unidades mientras esté suspendido.'
          : '${driver.fullName} volverá a estar disponible para operar.',
      confirmLabel: suspended ? 'Suspender' : 'Activar',
      destructive: suspended,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(driverRepositoryProvider)
          .updateDriver(
            id: driver.id,
            licenseNumber: driver.licenseNumber,
            status: action,
          );
      if (!mounted) return;
      showOperationSuccess(context, 'Estado del conductor actualizado.');
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }

  Future<void> _invite() async {
    final invited = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const InviteDriverDialog(),
    );
    if (invited == true && mounted) {
      showOperationSuccess(context, 'Invitación enviada al conductor.');
      _refresh();
    }
  }
}

class DriverFormDialog extends ConsumerStatefulWidget {
  const DriverFormDialog({super.key, required this.driver});
  final Driver driver;

  @override
  ConsumerState<DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends ConsumerState<DriverFormDialog> {
  late final TextEditingController _license;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _license = TextEditingController(text: widget.driver.licenseNumber);
    _status = widget.driver.status;
  }

  @override
  void dispose() {
    _license.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Editar ${widget.driver.fullName}'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _license,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Número de licencia'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Activo')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactivo')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspendido')),
            ],
            onChanged: (value) => _status = value!,
          ),
        ],
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .updateDriver(
            id: widget.driver.id,
            licenseNumber: _license.text.isEmpty ? null : _license.text,
            status: _status,
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

class AssignVehicleDialog extends ConsumerStatefulWidget {
  const AssignVehicleDialog({super.key, required this.driver});
  final Driver driver;

  @override
  ConsumerState<AssignVehicleDialog> createState() =>
      _AssignVehicleDialogState();
}

class _AssignVehicleDialogState extends ConsumerState<AssignVehicleDialog> {
  String? _vehicleId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.driver.vehicleId;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Asignar unidad a ${widget.driver.fullName}'),
    content: SizedBox(
      width: 480,
      child: FutureBuilder<PagedResult<Vehicle>>(
        future: ref
            .read(vehicleRepositoryProvider)
            .getVehicles(page: 0, pageSize: 200),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 180, child: LoadingPanel());
          }
          final vehicles = snapshot.data!.items
              .where(
                (vehicle) =>
                    vehicle.driverId == null ||
                    vehicle.driverId == widget.driver.id,
              )
              .toList();
          return DropdownButtonFormField<String?>(
            initialValue: _vehicleId,
            decoration: const InputDecoration(labelText: 'Unidad'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin unidad')),
              for (final vehicle in vehicles)
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text('${vehicle.code} · ${vehicle.plate}'),
                ),
            ],
            onChanged: (value) => _vehicleId = value,
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
        child: Text(_saving ? 'Asignando…' : 'Guardar asignación'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .assignDriverVehicle(widget.driver.id, _vehicleId);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showOperationError(context, error);
      }
    }
  }
}

class InviteDriverDialog extends ConsumerStatefulWidget {
  const InviteDriverDialog({super.key});

  @override
  ConsumerState<InviteDriverDialog> createState() => _InviteDriverDialogState();
}

class _InviteDriverDialogState extends ConsumerState<InviteDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _license = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _license.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invitar conductor'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se enviará una invitación mediante la función segura de Supabase. No se crea ningún administrador.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (value) => Validators.requiredText(value, 'El nombre'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _license,
              decoration: const InputDecoration(
                labelText: 'Número de licencia (opcional)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Enviando…' : 'Enviar invitación'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .inviteDriver(
            email: _email.text,
            fullName: _name.text,
            licenseNumber: _license.text.isEmpty ? null : _license.text,
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
