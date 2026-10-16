import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/services/inactivity_timer.dart';
import '../controllers/auth_controller.dart';
import '../controllers/providers.dart';

class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard>
    with WidgetsBindingObserver {
  late final InactivityTimer _timer;
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _hoverThrottle = Stopwatch();
  AuthStage? _lastStage;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = InactivityTimer(
      timeout: ref.read(appConfigProvider).inactivityTimeout,
      onTimeout: () {
        ref.read(authControllerProvider.notifier).lockForInactivity();
      },
    );
    _hoverThrottle.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.dispose();
    _codeFocus.dispose();
    _code.dispose();
    super.dispose();
  }

  void _syncStage(AuthStage stage) {
    if (_lastStage == stage) return;
    _lastStage = stage;
    if (stage == AuthStage.authenticated) {
      _code.clear();
      _lastActivity = DateTime.now();
      _timer.start();
    } else {
      _timer.stop();
    }
  }

  void _activity({bool throttle = false}) {
    if (throttle && _hoverThrottle.elapsed < const Duration(seconds: 1)) {
      return;
    }
    if (throttle) _hoverThrottle.reset();
    if (ref.read(authControllerProvider).stage == AuthStage.authenticated) {
      _lastActivity = DateTime.now();
      _timer.registerActivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_resumeSession());
  }

  Future<void> _resumeSession() async {
    if (ref.read(authControllerProvider).stage == AuthStage.authenticated &&
        DateTime.now().difference(_lastActivity) >=
            ref.read(appConfigProvider).inactivityTimeout) {
      _timer.stop();
      await ref.read(authControllerProvider.notifier).lockForInactivity();
    }
    if (mounted) {
      await ref.read(authControllerProvider.notifier).revalidateOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen<AuthViewState>(authControllerProvider, (previous, next) {
      if (previous?.busy == true &&
          !next.busy &&
          next.error != null &&
          isRetryableMfaErrorCode(next.errorCode)) {
        _code.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _codeFocus.requestFocus();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncStage(auth.stage);
    });
    final locked = auth.stage == AuthStage.locked;
    final blocked = locked || auth.checkingAccess;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, _) {
        _activity();
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onHover: (_) => _activity(throttle: true),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _activity(),
          onPointerSignal: (_) => _activity(),
          child: Stack(
            children: [
              AbsorbPointer(absorbing: blocked, child: widget.child),
              if (auth.checkingAccess)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
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
                                focusNode: _codeFocus,
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
