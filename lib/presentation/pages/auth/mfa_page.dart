import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../controllers/auth_controller.dart';

class MfaPage extends ConsumerStatefulWidget {
  const MfaPage({super.key, required this.enrollment});
  final bool enrollment;

  @override
  ConsumerState<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends ConsumerState<MfaPage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.enrollment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authControllerProvider.notifier).beginEnrollment();
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _svg(String value) {
    final comma = value.indexOf(',');
    return Uri.decodeFull(comma >= 0 ? value.substring(comma + 1) : value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final enrollment = state.enrollment;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.security, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        widget.enrollment
                            ? 'Protege tu cuenta administrativa'
                            : 'Verificación en dos pasos',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.enrollment
                            ? 'Escanea el código con tu aplicación autenticadora y escribe el código de 6 dígitos.'
                            : 'Escribe el código generado por tu aplicación autenticadora.',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.enrollment && enrollment == null) ...[
                        const SizedBox(height: 28),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (enrollment != null) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: ColoredBox(
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.string(
                                _svg(enrollment.qrCode),
                                width: 220,
                                height: 220,
                                semanticsLabel: 'Código QR para configurar MFA',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Si no puedes escanearlo, introduce esta clave manualmente:',
                          textAlign: TextAlign.center,
                        ),
                        SelectableText(
                          enrollment.secret,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextField(
                        controller: _code,
                        autofocus: !widget.enrollment,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          counterText: '',
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed:
                            state.busy ||
                                (widget.enrollment && enrollment == null)
                            ? null
                            : _verify,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: Text(
                          state.busy ? 'Verificando…' : 'Verificar y continuar',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : ref
                                  .read(authControllerProvider.notifier)
                                  .cancelMfaAndSignOut,
                        child: const Text('Cerrar sesión'),
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

  void _verify() {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) return;
    ref.read(authControllerProvider.notifier).verifyMfa(_code.text);
  }
}
