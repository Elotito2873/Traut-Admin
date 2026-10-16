import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';

class UnauthorizedPage extends ConsumerWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 18),
                Text(
                  'Tu cuenta no tiene permisos administrativos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'El acceso administrativo fue bloqueado. Solicita acceso al responsable de Supabase.',
                  textAlign: TextAlign.center,
                ),
                if (ref.watch(authControllerProvider).error
                    case final error?) ...[
                  const SizedBox(height: 12),
                  Text(error, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: ref
                      .read(authControllerProvider.notifier)
                      .returnToLogin,
                  child: const Text('Cerrar sesión e ir al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
