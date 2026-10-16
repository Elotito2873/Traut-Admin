import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/widgets/global_search_field.dart';

class _SearchRepository implements SearchRepository {
  final requests = <String>[];
  final pending = <String, Completer<List<GlobalSearchResult>>>{};

  @override
  Future<List<GlobalSearchResult>> search(String query) {
    requests.add(query);
    final completer = Completer<List<GlobalSearchResult>>();
    pending[query] = completer;
    return completer.future;
  }
}

GlobalSearchResult _result(String title) => GlobalSearchResult(
  id: title,
  title: title,
  subtitle: 'Prueba',
  type: 'Unidad',
  location: '/fleet',
);

void main() {
  testWidgets('debounce ignora respuesta antigua y borra al vaciar consulta', (
    tester,
  ) async {
    final repository = _SearchRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: GlobalSearchField())),
      ),
    );
    final field = find.byType(TextField);
    await tester.enterText(field, 'ab');
    await tester.pump(const Duration(milliseconds: 410));
    await tester.enterText(field, 'abc');
    await tester.pump(const Duration(milliseconds: 410));
    expect(repository.requests, ['ab', 'abc']);

    repository.pending['abc']!.complete([_result('Resultado nuevo')]);
    await tester.pump();
    repository.pending['ab']!.complete([_result('Resultado viejo')]);
    await tester.pump();
    expect(find.text('Resultado viejo'), findsNothing);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(find.text('Resultado nuevo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error de búsqueda se muestra sin detalles internos', (
    tester,
  ) async {
    final repository = _SearchRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: GlobalSearchField())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 410));
    repository.pending['abc']!.completeError(StateError('secreto interno'));
    await tester.pump();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('secreto interno'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
