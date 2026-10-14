import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traut_admin/data/repositories/supabase_repositories.dart';

void main() {
  test('getMetrics obtiene conteos sin descargar filas', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final table = request.url.pathSegments.last;
      final status = request.url.queryParameters['status'] ?? '';
      final count = switch ((table, status)) {
        ('vehicles', '') => 9,
        ('vehicles', 'eq.active') => 4,
        ('vehicles', 'eq.maintenance') => 1,
        ('vehicles', 'eq.no_signal') => 2,
        ('routes', 'eq.true') => 3,
        ('drivers', 'eq.active') => 5,
        ('trips', 'eq.active') => 2,
        ('incidents', _) => 6,
        _ => 0,
      };
      return http.Response(
        '',
        200,
        headers: {'content-range': '0-0/$count'},
        request: request,
      );
    });
    final supabase = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: client,
    );
    final repository = SupabaseAdminRepository(supabase);

    final metrics = await repository.getMetrics();

    expect(metrics.totalVehicles, 9);
    expect(metrics.activeVehicles, 4);
    expect(metrics.openIncidents, 6);
    expect(requests, hasLength(8));
    expect(requests.every((request) => request.method == 'HEAD'), isTrue);
  });
}
