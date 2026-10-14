import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key, required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Falta configurar Traut Admin',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...config.validationErrors.map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $error'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SelectableText(
                      'Copia config/example.json a config/dev.json, completa los valores y ejecuta:\n\n'
                      'flutter run -d linux --dart-define-from-file=config/dev.json',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
