import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  String? _status;
  int _page = 0;
  int _pageSize = 25;

  TripQuery get _query =>
      TripQuery(page: _page, pageSize: _pageSize, status: _status);

  void _refresh() {
    ref.invalidate(tripsProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider(_query));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            title: 'Viajes',
            subtitle: 'Consulta la operación y atiende viajes activos.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'active', child: Text('Activos')),
                DropdownMenuItem(value: 'finished', child: Text('Finalizados')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelados')),
              ],
              onChanged: (value) => setState(() {
                _status = value;
                _page = 0;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: trips.when(
                loading: () => const LoadingPanel(),
                error: (error, _) =>
                    ErrorPanel(error: error, onRetry: _refresh),
                data: (result) {
                  final items = result.items;
                  if (items.isEmpty) {
                    return const EmptyPanel(
                      message: 'No hay viajes para este filtro.',
                      icon: Icons.route_outlined,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Unidad')),
                                DataColumn(label: Text('Ruta')),
                                DataColumn(label: Text('Conductor')),
                                DataColumn(label: Text('Inicio')),
                                DataColumn(label: Text('Fin')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: [
                                for (final trip in items)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(trip.vehicleCode ?? 'Sin unidad'),
                                      ),
                                      DataCell(
                                        Text(trip.routeName ?? 'Sin ruta'),
                                      ),
                                      DataCell(
                                        Text(
                                          trip.driverName ?? 'Sin conductor',
                                        ),
                                      ),
                                      DataCell(Text(_date(trip.startedAt))),
                                      DataCell(Text(_date(trip.endedAt))),
                                      DataCell(
                                        StatusBadge(status: trip.status),
                                      ),
                                      DataCell(
                                        trip.status == 'active'
                                            ? PopupMenuButton<String>(
                                                tooltip: 'Acciones del viaje',
                                                onSelected: (status) =>
                                                    _changeStatus(trip, status),
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(
                                                    value: 'finished',
                                                    child: Text(
                                                      'Finalizar viaje',
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'cancelled',
                                                    child: Text(
                                                      'Cancelar viaje',
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Text('Histórico'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PagedTableFooter<Trip>(
                        result: result,
                        onPageSize: (value) => setState(() {
                          _pageSize = value;
                          _page = 0;
                        }),
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

  String _date(DateTime? value) => value == null
      ? 'Sin registrar'
      : DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());

  Future<void> _changeStatus(Trip trip, String status) async {
    final cancel = status == 'cancelled';
    final confirmed = await confirmAction(
      context,
      title: cancel ? 'Cancelar viaje' : 'Finalizar viaje',
      message: cancel
          ? 'El viaje quedará cancelado y se conservará en el historial.'
          : 'El viaje quedará finalizado con la hora actual.',
      confirmLabel: cancel ? 'Cancelar viaje' : 'Finalizar viaje',
      destructive: cancel,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(tripRepositoryProvider).updateTripStatus(trip.id, status);
      if (!mounted) return;
      showOperationSuccess(context, 'Viaje actualizado.');
      _refresh();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }
}
