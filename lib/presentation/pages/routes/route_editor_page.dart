import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/validators.dart';
import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/transport_map.dart';
import 'routes_page.dart';

List<T> reorderItems<T>(List<T> source, int oldIndex, int newIndex) {
  final items = [...source];
  final item = items.removeAt(oldIndex);
  items.insert(newIndex, item);
  return items;
}

int nextStopOrder(Iterable<RouteStop> stops) =>
    stops.fold<int>(
      0,
      (highest, stop) => stop.order > highest ? stop.order : highest,
    ) +
    1;

class RouteEditorPage extends ConsumerStatefulWidget {
  const RouteEditorPage({super.key, required this.routeId});
  final String routeId;

  @override
  ConsumerState<RouteEditorPage> createState() => _RouteEditorPageState();
}

class _RouteEditorPageState extends ConsumerState<RouteEditorPage> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(routeProvider(widget.routeId));
    ref.invalidate(routesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider(widget.routeId));
    return Padding(
      padding: responsivePagePadding(context),
      child: route.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(error: error, onRetry: _refresh),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageIntro(
              title: data.name,
              subtitle:
                  '${data.origin} → ${data.destination}. La línea une paradas; no representa navegación por calles.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/routes'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editRoute(data),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar ruta'),
                ),
                FilledButton.icon(
                  onPressed: () => _editStop(data),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Nueva parada'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return ListView(
                      children: [
                        SizedBox(height: 430, child: _map(data)),
                        const SizedBox(height: 14),
                        SizedBox(height: 520, child: _stopList(data)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 390, child: _stopList(data)),
                      const SizedBox(width: 14),
                      Expanded(child: _map(data)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _map(TransportRoute route) => Card(
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: TransportMap(
            config: ref.watch(appConfigProvider),
            stops: route.stops,
            routeColor: route.color,
            mapController: _mapController,
            onStopSelected: (stop) =>
                _mapController.move(LatLng(stop.latitude, stop.longitude), 16),
            onMapTap: (position) => _editStop(route, coordinate: position),
          ),
        ),
        Positioned(
          left: 12,
          right: 76,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Haz clic en el mapa para agregar una parada',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stopList(TransportRoute route) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paradas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${route.stops.length} registradas · arrastra para reordenar'),
          if (route.invalidStopCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${route.invalidStopCount} parada(s) no se muestran por coordenadas inválidas.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const Divider(height: 22),
          Expanded(
            child: route.stops.isEmpty
                ? const EmptyPanel(
                    message:
                        'Aún no hay paradas. Usa “Nueva parada” o selecciona una posición en el mapa.',
                    icon: Icons.add_location_alt_outlined,
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: route.stops.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        _reorder(route.stops, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final stop = route.stops[index];
                      return ListTile(
                        key: ValueKey(stop.id),
                        minTileHeight: 68,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(stop.name),
                        subtitle: Text(
                          '\$${stop.fare.toStringAsFixed(2)} · '
                          '${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}',
                        ),
                        onTap: () {
                          _mapController.move(
                            LatLng(stop.latitude, stop.longitude),
                            16,
                          );
                        },
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'Editar ${stop.name}',
                              onPressed: () => _editStop(route, stop: stop),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Eliminar ${stop.name}',
                              onPressed: () => _deleteStop(stop),
                              icon: const Icon(Icons.delete_outline),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editRoute(TransportRoute route) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => RouteFormDialog(route: route),
    );
    if (saved != null) _refresh();
  }

  Future<void> _editStop(
    TransportRoute route, {
    RouteStop? stop,
    LatLng? coordinate,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StopFormDialog(
        routeId: route.id,
        nextOrder: nextStopOrder(route.stops),
        stop: stop,
        coordinate: coordinate,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _deleteStop(RouteStop stop) async {
    final confirmed = await confirmAction(
      context,
      title: 'Eliminar parada',
      message:
          'Se eliminará “${stop.name}” de la ruta. Esta acción es permanente y puede afectar a pasajeros.',
      confirmLabel: 'Eliminar parada',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(routeRepositoryProvider).deleteStop(stop.id);
      if (!mounted) return;
      showOperationSuccess(context, 'Parada eliminada.');
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }

  Future<void> _reorder(
    List<RouteStop> source,
    int oldIndex,
    int newIndex,
  ) async {
    final stops = reorderItems(source, oldIndex, newIndex);
    try {
      await ref.read(routeRepositoryProvider).reorderStops(stops);
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }
}

class StopFormDialog extends ConsumerStatefulWidget {
  const StopFormDialog({
    super.key,
    required this.routeId,
    required this.nextOrder,
    this.stop,
    this.coordinate,
  });
  final String routeId;
  final int nextOrder;
  final RouteStop? stop;
  final LatLng? coordinate;

  @override
  ConsumerState<StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends ConsumerState<StopFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _fare;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.stop?.name);
    _latitude = TextEditingController(
      text: (widget.coordinate?.latitude ?? widget.stop?.latitude)?.toString(),
    );
    _longitude = TextEditingController(
      text: (widget.coordinate?.longitude ?? widget.stop?.longitude)
          ?.toString(),
    );
    _fare = TextEditingController(
      text: (widget.stop?.fare ?? 0).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _fare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.stop == null ? 'Nueva parada' : 'Editar parada'),
    content: SizedBox(
      width: responsiveDialogWidth(context, 520),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    Validators.requiredText(value, 'El nombre'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitude,
                      decoration: const InputDecoration(labelText: 'Latitud'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) =>
                          Validators.coordinate(value, latitude: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitude,
                      decoration: const InputDecoration(labelText: 'Longitud'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) =>
                          Validators.coordinate(value, latitude: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fare,
                decoration: const InputDecoration(
                  labelText: 'Tarifa',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: Validators.money,
              ),
              const SizedBox(height: 10),
              const Text(
                'El orden puede ajustarse arrastrando la parada en la lista.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar parada'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(routeRepositoryProvider)
          .saveStop(
            id: widget.stop?.id,
            routeId: widget.routeId,
            name: _name.text,
            latitude: double.parse(_latitude.text),
            longitude: double.parse(_longitude.text),
            order: widget.stop?.order ?? widget.nextOrder,
            fare: double.parse(_fare.text),
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
