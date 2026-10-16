import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';
import 'package:traut_admin/presentation/pages/drivers/drivers_page.dart';
import 'package:traut_admin/presentation/pages/fleet/fleet_page.dart';
import 'package:traut_admin/presentation/pages/routes/route_editor_page.dart';
import 'package:traut_admin/presentation/pages/routes/routes_page.dart';
import 'package:traut_admin/presentation/widgets/paged_entity_picker.dart';

class _RouteRepository implements RouteRepository {
  int calls = 0;

  @override
  Future<List<TransportRoute>> getRoutes({String search = ''}) async {
    calls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('formularios principales caben en ventana de 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final driver = Driver(
      id: 'driver-1',
      profileId: 'profile-1',
      fullName: 'Conductor',
      email: 'driver@example.com',
      status: 'active',
      createdAt: DateTime.utc(2026),
    );
    for (final dialog in [
      const VehicleFormDialog(),
      DriverFormDialog(driver: driver),
      AssignVehicleDialog(driver: driver),
      const RouteFormDialog(),
      const StopFormDialog(routeId: 'route-1', nextOrder: 1),
      const InviteDriverDialog(),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeRepositoryProvider.overrideWithValue(_RouteRepository()),
          ],
          child: MaterialApp(home: Scaffold(body: dialog)),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: dialog.runtimeType.toString(),
      );
    }
  });

  testWidgets('formulario no repite consulta de rutas al editar campos', (
    tester,
  ) async {
    final routes = _RouteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routeRepositoryProvider.overrideWithValue(routes)],
        child: const MaterialApp(home: Scaffold(body: VehicleFormDialog())),
      ),
    );
    await tester.pump();
    expect(routes.calls, 1);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código'),
      'U-01',
    );
    await tester.pump();
    expect(routes.calls, 1);
  });

  testWidgets('selector remoto permite avanzar más allá de la primera página', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int? chosen;
    final pages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showPagedEntityPicker<int>(
                  context,
                  title: 'Buscar registro',
                  load: (page, query) async {
                    pages.add(page);
                    return PagedResult(
                      items: List.generate(20, (index) => page * 20 + index),
                      total: 250,
                      page: page,
                      pageSize: 20,
                    );
                  },
                  label: (item) => 'Registro $item',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2'), findsOneWidget);
    await tester.tap(find.text('Registro 20'));
    await tester.pumpAndSettle();
    expect(chosen, 20);
    expect(pages, [0, 1]);
    expect(tester.takeException(), isNull);
  });
}
