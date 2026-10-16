import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/transport_entities.dart';
import 'common_widgets.dart';

Future<T?> showPagedEntityPicker<T>(
  BuildContext context, {
  required String title,
  required Future<PagedResult<T>> Function(int page, String query) load,
  required String Function(T item) label,
}) => showDialog<T>(
  context: context,
  builder: (_) => _PagedEntityPicker<T>(title: title, load: load, label: label),
);

class _PagedEntityPicker<T> extends StatefulWidget {
  const _PagedEntityPicker({
    required this.title,
    required this.load,
    required this.label,
  });

  final String title;
  final Future<PagedResult<T>> Function(int page, String query) load;
  final String Function(T item) label;

  @override
  State<_PagedEntityPicker<T>> createState() => _PagedEntityPickerState<T>();
}

class _PagedEntityPickerState<T> extends State<_PagedEntityPicker<T>> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<PagedResult<T>> _result;
  String _query = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _result = widget.load(_page, _query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load({int? page, String? query}) {
    setState(() {
      _page = page ?? _page;
      _query = query ?? _query;
      _result = widget.load(_page, _query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: responsiveDialogWidth(context, 440),
        height: (size.height * 0.55).clamp(220.0, 440.0),
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) _load(page: 0, query: value.trim());
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<PagedResult<T>>(
                future: _result,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(userFriendlyError(snapshot.error!)),
                          TextButton(
                            onPressed: () => _load(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final result = snapshot.data!;
                  return Column(
                    children: [
                      Expanded(
                        child: result.items.isEmpty
                            ? const Center(child: Text('Sin coincidencias'))
                            : ListView.builder(
                                itemCount: result.items.length,
                                itemBuilder: (context, index) {
                                  final item = result.items[index];
                                  return ListTile(
                                    title: Text(widget.label(item)),
                                    onTap: () => Navigator.pop(context, item),
                                  );
                                },
                              ),
                      ),
                      Text('${result.total} resultados'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'Página anterior',
                            onPressed: _page > 0
                                ? () => _load(page: _page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              'Página ${_page + 1}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Página siguiente',
                            onPressed: result.hasNext
                                ? () => _load(page: _page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
