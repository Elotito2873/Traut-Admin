import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/transport_entities.dart';
import '../controllers/providers.dart';

class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key});

  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  Timer? _debounce;
  List<GlobalSearchResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await ref.read(searchRepositoryProvider).search(value);
        if (mounted) setState(() => _results = results);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Autocomplete<GlobalSearchResult>(
        displayStringForOption: (option) => option.title,
        optionsBuilder: (_) => _results,
        onSelected: (result) => context.go(result.location),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: _search,
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: InputDecoration(
                hintText: 'Buscar unidad, placa, ruta o conductor',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      minTileHeight: 56,
                      leading: Icon(switch (option.type) {
                        'Unidad' => Icons.directions_bus_outlined,
                        'Ruta' => Icons.alt_route,
                        _ => Icons.badge_outlined,
                      }),
                      title: Text(option.title),
                      subtitle: Text('${option.type} · ${option.subtitle}'),
                      onTap: () => onSelected(option),
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
