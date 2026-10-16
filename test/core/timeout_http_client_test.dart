import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traut_admin/core/services/timeout_http_client.dart';

void main() {
  test('timeout HTTP termina espera sin reintentar la petición', () async {
    var calls = 0;
    final client = TimeoutHttpClient(
      MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('ok', 200, request: request);
      }),
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.https('example.com')),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
  });

  test('timeout HTTP cubre también un cuerpo que no termina', () async {
    final client = TimeoutHttpClient(
      _SlowBodyClient(),
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.https('example.com')),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class _SlowBodyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.periodic(
          const Duration(milliseconds: 40),
          (_) => [1],
        ).take(1),
        200,
        request: request,
      );
}
