import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/inactivity_timer.dart';
import '../controllers/auth_controller.dart';
import '../controllers/providers.dart';

class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  late final InactivityTimer _timer;
  final _code = TextEditingController();
  AuthStage? _lastStage;

  @override
  void initState() {
    super.initState();
    _timer = InactivityTimer(
      timeout: ref.read(appConfigProvider).inactivityTimeout,
      onTimeout: () {
        ref.read(authControllerProvider.notifier).lockForInactivity();
      },
    );
  }

  @override
  void dispose() {
    _timer.dispose();
    _code.dispose();
    super.dispose();
  }

  void _syncStage(AuthStage stage) {
    if (_lastStage == stage) return;
    _lastStage = stage;
    if (stage == AuthStage.authenticated) {
      _code.clear();
      _timer.start();
    } else {
      _timer.stop();
    }
  }

  void _activity() {
    if (ref.read(authControllerProvider).stage == AuthStage.authenticated) {
      _timer.registerActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncStage(auth.stage);
    });
    final locked = auth.stage == AuthStage.locked;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, _) {
        _activity();
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onHover: (_) => _activity(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _activity(),
          onPointerSignal: (_) => _activity(),
          child: Stack(
            children: [
              AbsorbPointer(absorbing: locked, child: widget.child),
              if (locked) ...[
                const Positioned.fill(
                  child: ModalBarrier(
                    dismissible: false,
                    color: Colors.black54,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_clock_outlined, size: 48),
                              const SizedBox(height: 14),
                              Text(
                                'Traut Admin está bloqueado',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'La sesión quedó inactiva. Verifica nuevamente tu código MFA; los formularios abiertos se conservarán.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _code,
                                autofocus: true,
                                enabled: !auth.busy,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Código de 6 dígitos',
                                  errorText: auth.error,
                                ),
                                onSubmitted: (_) => _unlock(auth.busy),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: auth.busy
                                        ? null
                                        : ref
                                              .read(
                                                authControllerProvider.notifier,
                                              )
                                              .signOut,
                                    child: const Text('Cerrar sesión'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: auth.busy
                                        ? null
                                        : () => _unlock(false),
                                    child: Text(
                                      auth.busy
                                          ? 'Verificando…'
                                          : 'Desbloquear',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _unlock(bool busy) {
    if (busy || _code.text.trim().length != 6) return;
    ref.read(authControllerProvider.notifier).verifyMfa(_code.text);
  }
}
