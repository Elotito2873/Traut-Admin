import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class IncidentsPage extends ConsumerStatefulWidget {
  const IncidentsPage({super.key});

  @override
  ConsumerState<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends ConsumerState<IncidentsPage> {
  String? _status;
  int _page = 0;
  int _pageSize = 25;

  IncidentQuery get _query =>
      IncidentQuery(page: _page, pageSize: _pageSize, status: _status);

  void _refresh() {
    ref.invalidate(incidentsProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider(_query));
    return Padding(
      padding: responsivePagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            title: 'Incidencias',
            subtitle:
                'Revisa reportes operativos y conserva su historial de resolución.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(value: 'open', child: Text('Abiertas')),
                DropdownMenuItem(
                  value: 'reviewing',
                  child: Text('En revisión'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Resueltas')),
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
              child: incidents.when(
                loading: () => const LoadingPanel(),
                error: (error, _) =>
                    ErrorPanel(error: error, onRetry: _refresh),
                data: (result) {
                  final items = result.items;
                  if (items.isEmpty) {
                    return const EmptyPanel(
                      message: 'No hay incidencias para este filtro.',
                      icon: Icons.task_alt,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              constraints.maxWidth < 900
                              ? ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final incident = items[index];
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
                                                    incident.type,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                ),
                                                StatusBadge(
                                                  status: incident.status,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              incident.description ??
                                                  'Sin descripción',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Unidad: ${incident.vehicleCode ?? 'Sin unidad'}',
                                            ),
                                            Text(
                                              'Conductor: ${incident.driverName ?? 'Sin conductor'}',
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: () =>
                                                    _openDetail(incident),
                                                child: const Text(
                                                  'Abrir detalle',
                                                ),
                                              ),
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
                                        DataColumn(label: Text('Fecha')),
                                        DataColumn(label: Text('Unidad')),
                                        DataColumn(label: Text('Conductor')),
                                        DataColumn(label: Text('Tipo')),
                                        DataColumn(label: Text('Descripción')),
                                        DataColumn(label: Text('Estado')),
                                        DataColumn(label: Text('Acciones')),
                                      ],
                                      rows: [
                                        for (final incident in items)
                                          DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  incident.createdAt == null
                                                      ? 'Fecha no disponible'
                                                      : DateFormat(
                                                          'dd/MM/yyyy HH:mm',
                                                        ).format(
                                                          incident.createdAt!
                                                              .toLocal(),
                                                        ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  incident.vehicleCode ??
                                                      'Sin unidad',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  incident.driverName ??
                                                      'Sin conductor',
                                                ),
                                              ),
                                              DataCell(Text(incident.type)),
                                              DataCell(
                                                SizedBox(
                                                  width: 260,
                                                  child: Text(
                                                    incident.description ??
                                                        'Sin descripción',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                StatusBadge(
                                                  status: incident.status,
                                                ),
                                              ),
                                              DataCell(
                                                FilledButton.tonal(
                                                  onPressed: () =>
                                                      _openDetail(incident),
                                                  child: const Text(
                                                    'Abrir detalle',
                                                  ),
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
                      PagedTableFooter<Incident>(
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

  Future<void> _openDetail(Incident incident) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncidentDetailDialog(incident: incident),
    );
    if (updated == true) _refresh();
  }
}

class IncidentDetailDialog extends ConsumerStatefulWidget {
  const IncidentDetailDialog({super.key, required this.incident});
  final Incident incident;

  @override
  ConsumerState<IncidentDetailDialog> createState() =>
      _IncidentDetailDialogState();
}

class _IncidentDetailDialogState extends ConsumerState<IncidentDetailDialog> {
  late String _status;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.incident.status;
    _notes = TextEditingController(text: widget.incident.resolutionNotes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Incidencia: ${widget.incident.type}'),
    content: SizedBox(
      width: responsiveDialogWidth(context, 600),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(
              label: 'Unidad',
              value: widget.incident.vehicleCode ?? 'Sin unidad',
            ),
            _DetailRow(
              label: 'Conductor',
              value: widget.incident.driverName ?? 'Sin conductor',
            ),
            _DetailRow(
              label: 'Fecha',
              value: widget.incident.createdAt == null
                  ? 'Fecha no disponible'
                  : DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(widget.incident.createdAt!.toLocal()),
            ),
            const SizedBox(height: 8),
            Text(
              widget.incident.description ?? 'Sin descripción',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Divider(height: 28),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Abierta')),
                DropdownMenuItem(
                  value: 'reviewing',
                  child: Text('En revisión'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Resuelta')),
              ],
              onChanged: (value) => setState(() => _status = value!),
            ),
            if (_status == 'resolved') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notas de resolución',
                  hintText: 'Describe cómo se atendió la incidencia',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar estado'),
      ),
    ],
  );

  Future<void> _save() async {
    if (_status == 'resolved' && _notes.text.trim().isEmpty) {
      showOperationError(
        context,
        const AppException('Escribe una nota de resolución.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(updateIncidentUseCaseProvider)
          .call(
            incidentId: widget.incident.id,
            status: _status,
            resolutionNotes: _notes.text,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
