import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/config/app_config.dart';

void main() {
  test('acepta clave publicable y JWT anon heredado', () {
    expect(AppConfig.isSafeClientKey('sb_publishable_example'), isTrue);
    expect(AppConfig.isSafeClientKey(_jwt('anon')), isTrue);
  });

  test('rechaza service_role, sb_secret y valores inválidos', () {
    expect(AppConfig.isSafeClientKey('sb_secret_example'), isFalse);
    expect(AppConfig.isSafeClientKey(_jwt('service_role')), isFalse);
    expect(AppConfig.isSafeClientKey('not-a-client-key'), isFalse);
  });

  test('valida URL de tiles HTTPS con sus tres placeholders', () {
    const config = AppConfig(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_example',
      requireAdminMfa: false,
      tileUrl: 'http://tiles.example.com/{z}/{x}.png',
      osmUserAgent: 'test',
    );

    expect(config.isValid, isFalse);
    expect(config.validationErrors, contains(contains('OSM_TILE_URL')));
  });
}

String _jwt(String role) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'role': role})}.signature';
}
