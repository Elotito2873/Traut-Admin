import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/presentation/pages/routes/route_editor_page.dart';

void main() {
  test('onReorderItem ya entrega el índice ajustado en Flutter 3.44', () {
    expect(reorderItems(['A', 'B', 'C'], 0, 2), ['B', 'C', 'A']);
    expect(reorderItems(['A', 'B', 'C'], 2, 0), ['C', 'A', 'B']);
    expect(reorderItems(['A', 'B', 'C'], 1, 2), ['A', 'C', 'B']);
    expect(reorderItems(['A', 'B', 'C'], 1, 0), ['B', 'A', 'C']);
  });

  test('delete + alta usa máximo orden y no choca con huecos', () {
    final stops = [1, 3].map(
      (order) => RouteStop(
        id: '$order',
        routeId: 'r1',
        name: 'Parada $order',
        latitude: 19,
        longitude: -99,
        order: order,
        fare: 10,
      ),
    );
    expect(nextStopOrder(stops), 4);
    expect(nextStopOrder(const []), 1);
  });
}
