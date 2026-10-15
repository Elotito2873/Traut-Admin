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
      defaultValue: 'false',
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
        supabasePublishableKey.isNotEmpty &&
        !supabasePublishableKey.contains('your_key');
  }

  List<String> get validationErrors {
    final errors = <String>[];
    if (Uri.tryParse(supabaseUrl)?.isScheme('https') != true) {
      errors.add('SUPABASE_URL debe ser una URL HTTPS válida.');
    }
    if (supabasePublishableKey.isEmpty ||
        supabasePublishableKey.contains('your_key')) {
      errors.add('SUPABASE_PUBLISHABLE_KEY no está configurada.');
    }
    return errors;
  }
}
