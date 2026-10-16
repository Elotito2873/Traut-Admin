import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/timeout_http_client.dart';
import 'presentation/controllers/providers.dart';
import 'presentation/pages/auth/configuration_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    runApp(ConfigurationPage(config: config));
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    httpClient: TimeoutHttpClient(http.Client()),
    authOptions: const FlutterAuthClientOptions(
      // Un panel administrativo no debe dejar refresh tokens en disco.
      persistSession: false,
      // Traut Admin no usa callbacks OAuth/magic-link en la URL.
      detectSessionInUri: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const TrautAdminApp(),
    ),
  );
}
