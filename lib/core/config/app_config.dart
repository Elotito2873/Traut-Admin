import 'dart:convert';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.requireAdminMfa,
    required this.tileUrl,
    required this.osmUserAgent,
    this.inactivityTimeout = const Duration(minutes: 20),
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const requireMfa = String.fromEnvironment(
      'REQUIRE_ADMIN_MFA',
      defaultValue: 'true',
    );
    const tileUrl = String.fromEnvironment(
      'OSM_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    const userAgent = String.fromEnvironment(
      'OSM_USER_AGENT',
      defaultValue: 'com.traut.admin',
    );
    const timeoutText = String.fromEnvironment(
      'ADMIN_INACTIVITY_TIMEOUT_MINUTES',
      defaultValue: '20',
    );
    final timeoutMinutes = int.tryParse(timeoutText);
    return AppConfig(
      supabaseUrl: url,
      supabasePublishableKey: key,
      requireAdminMfa: requireMfa == 'true',
      tileUrl: tileUrl,
      osmUserAgent: userAgent,
      inactivityTimeout: Duration(
        minutes: timeoutMinutes != null && timeoutMinutes > 0
            ? timeoutMinutes
            : 20,
      ),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final bool requireAdminMfa;
  final String tileUrl;
  final String osmUserAgent;
  final Duration inactivityTimeout;

  bool get isValid {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        isSafeClientKey(supabasePublishableKey) &&
        _isValidTileUrl(tileUrl) &&
        osmUserAgent.trim().isNotEmpty;
  }

  List<String> get validationErrors {
    final errors = <String>[];
    final supabaseUri = Uri.tryParse(supabaseUrl);
    if (supabaseUri == null ||
        !supabaseUri.isScheme('https') ||
        supabaseUri.host.isEmpty) {
      errors.add('SUPABASE_URL debe ser una URL HTTPS válida.');
    }
    if (supabasePublishableKey.isEmpty ||
        supabasePublishableKey.contains('your_key')) {
      errors.add('SUPABASE_PUBLISHABLE_KEY no está configurada.');
    } else if (!isSafeClientKey(supabasePublishableKey)) {
      errors.add(
        'SUPABASE_PUBLISHABLE_KEY debe ser una clave publicable o anon; '
        'nunca uses service_role ni sb_secret_ en el cliente.',
      );
    }
    if (!_isValidTileUrl(tileUrl)) {
      errors.add('OSM_TILE_URL debe ser HTTPS e incluir {z}, {x} y {y}.');
    }
    if (osmUserAgent.trim().isEmpty) {
      errors.add('OSM_USER_AGENT no puede estar vacío.');
    }
    return errors;
  }

  /// Acepta claves publicables modernas o el JWT `anon` heredado. Rechaza
  /// secretos de servidor incluso si se pegan accidentalmente en la config.
  static bool isSafeClientKey(String key) {
    final value = key.trim();
    if (value.isEmpty || value.contains('your_key')) return false;
    if (value.startsWith('sb_secret_')) return false;
    if (value.startsWith('sb_publishable_')) return true;

    final parts = value.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      return json is Map && json['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  static bool _isValidTileUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        value.contains('{z}') &&
        value.contains('{x}') &&
        value.contains('{y}');
  }
}
