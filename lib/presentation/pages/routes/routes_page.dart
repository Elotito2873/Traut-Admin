import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/color_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider(_search));
    return Padding(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageIntro(
            title: 'Rutas',
            subtitle: 'Gestiona recorridos, paradas, orden y tarifas.',
            actions: [
              FilledButton.icon(
                onPressed: () => _editRoute(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva ruta'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: responsiveFieldWidth(context, 380),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar ruta, origen o destino',
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
          const SizedBox(height: 16),
          Expanded(
            child: routes.when(
              loading: () => const LoadingPanel(),
              error: (error, _) => ErrorPanel(
                error: error,
                onRetry: () => ref.invalidate(routesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyPanel(
                    message: 'No hay rutas que coincidan con la búsqueda.',
                    icon: Icons.alt_route,
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1050
                        ? 3
                        : constraints.maxWidth >= 650
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 14) / columns;
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final route in items)
                            SizedBox(
                              width: width,
                              child: _RouteCard(
                                route: route,
                                onOpen: () => context.go('/routes/${route.id}'),
                                onEdit: () => _editRoute(route),
                                onToggle: () => _toggleRoute(route),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _refresh() {
    ref.invalidate(routesProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _editRoute([TransportRoute? route]) async {
    final routeId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RouteFormDialog(route: route),
    );
    if (routeId != null && mounted) {
      _refresh();
      if (route == null) context.go('/routes/$routeId');
    }
  }

  Future<void> _toggleRoute(TransportRoute route) async {
    final action = route.active ? 'desactivar' : 'activar';
    final confirmed = await confirmAction(
      context,
      title: '${route.active ? 'Desactivar' : 'Activar'} ruta',
      message:
          '¿Deseas $action “${route.name}”? Las aplicaciones conectadas verán el nuevo estado.',
      confirmLabel: 'Sí, $action',
      destructive: route.active,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(routeRepositoryProvider)
          .setRouteActive(route.id, !route.active);
      if (!mounted) return;
      showOperationSuccess(context, 'Ruta actualizada.');
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
  });
  final TransportRoute route;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorFromHex(route.color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(value: route.active, onChanged: (_) => onToggle()),
              ],
            ),
            const SizedBox(height: 14),
            Text('${route.origin} → ${route.destination}'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _Info(
                  icon: Icons.pin_drop_outlined,
                  text: '${route.stops.length} paradas',
                ),
                _Info(
                  icon: Icons.directions_bus_outlined,
                  text: '${route.vehicleCount} unidades',
                ),
                _Info(
                  icon: Icons.payments_outlined,
                  text: '\$${route.maximumFare.toStringAsFixed(2)} máx.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.route),
                  label: const Text('Paradas'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 18), const SizedBox(width: 5), Text(text)],
  );
}

class RouteFormDialog extends ConsumerStatefulWidget {
  const RouteFormDialog({super.key, this.route});
  final TransportRoute? route;

  @override
  ConsumerState<RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends ConsumerState<RouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _origin;
  late final TextEditingController _destination;
  late final TextEditingController _color;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.route?.name);
    _origin = TextEditingController(text: widget.route?.origin);
    _destination = TextEditingController(text: widget.route?.destination);
    _color = TextEditingController(text: widget.route?.color ?? '#4F46E5');
    _active = widget.route?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _origin.dispose();
    _destination.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.route == null ? 'Nueva ruta' : 'Editar ruta'),
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
              TextFormField(
                controller: _origin,
                decoration: const InputDecoration(labelText: 'Origen'),
                validator: (value) =>
                    Validators.requiredText(value, 'El origen'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destination,
                decoration: const InputDecoration(labelText: 'Destino'),
                validator: (value) =>
                    Validators.requiredText(value, 'El destino'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _color,
                decoration: InputDecoration(
                  labelText: 'Color (#RRGGBB)',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorFromHex(_color.text),
                      ),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: Validators.hexColor,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ruta activa'),
                subtitle: const Text(
                  'Visible para las aplicaciones autorizadas',
                ),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(routeRepositoryProvider)
          .saveRoute(
            id: widget.route?.id,
            name: _name.text,
            origin: _origin.text,
            destination: _destination.text,
            color: _color.text,
            active: _active,
          );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showOperationError(context, error);
      }
    }
  }
}
