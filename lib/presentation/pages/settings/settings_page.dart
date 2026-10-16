import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/repositories/repositories.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeModeProvider);
    final totp = ref.watch(verifiedTotpProvider);
    return ListView(
      padding: responsivePagePadding(context),
      children: [
        const PageIntro(
          title: 'Configuración',
          subtitle: 'Preferencias locales y seguridad de tu cuenta.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apariencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 440) {
                      return DropdownButtonFormField<ThemeMode>(
                        isExpanded: true,
                        initialValue: theme,
                        decoration: const InputDecoration(labelText: 'Tema'),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Sistema'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Claro'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Oscuro'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(themeModeProvider.notifier).setMode(value);
                          }
                        },
                      );
                    }
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.computer),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Oscuro'),
                        ),
                      ],
                      selected: {theme},
                      onSelectionChanged: (selection) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(selection.first),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final description = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autenticación en dos pasos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Agrega un factor TOTP oficial de Supabase a tu cuenta.',
                    ),
                  ],
                );
                final button = totp.when(
                  loading: () => const Text('Comprobando MFA…'),
                  error: (_, _) => TextButton.icon(
                    onPressed: () => ref.invalidate(verifiedTotpProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar MFA'),
                  ),
                  data: (factorId) => factorId == null
                      ? FilledButton.tonal(
                          onPressed: () async {
                            await showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const MfaEnrollmentDialog(),
                            );
                            ref.invalidate(verifiedTotpProvider);
                          },
                          child: const Text('Configurar MFA'),
                        )
                      : const Chip(
                          avatar: Icon(Icons.verified_user_outlined),
                          label: Text('MFA configurado'),
                        ),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security, size: 38),
                      const SizedBox(height: 12),
                      description,
                      const SizedBox(height: 16),
                      button,
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(Icons.security, size: 38),
                    const SizedBox(width: 16),
                    Expanded(child: description),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) => ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const Icon(Icons.info_outline, size: 38),
              title: const Text('Acerca de Traut Admin'),
              subtitle: Text(
                snapshot.hasData
                    ? 'Versión ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : 'Consultando versión…',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MfaEnrollmentDialog extends ConsumerStatefulWidget {
  const MfaEnrollmentDialog({super.key});

  @override
  ConsumerState<MfaEnrollmentDialog> createState() =>
      _MfaEnrollmentDialogState();
}

class _MfaEnrollmentDialogState extends ConsumerState<MfaEnrollmentDialog> {
  final _code = TextEditingController();
  MfaEnrollment? _enrollment;
  Object? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    Future<void>(_start);
  }

  Future<void> _start() async {
    try {
      final value = await ref.read(authRepositoryProvider).enrollMfa();
      if (mounted) setState(() => _enrollment = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _svg(String value) {
    final comma = value.indexOf(',');
    return Uri.decodeFull(comma >= 0 ? value.substring(comma + 1) : value);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Configurar autenticación TOTP'),
    content: SizedBox(
      width: responsiveDialogWidth(context, 480),
      child: _busy
          ? const SizedBox(height: 260, child: LoadingPanel())
          : _enrollment == null
          ? Text(
              userFriendlyError(
                _error ?? const AppException('No fue posible iniciar MFA.'),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Escanea el QR con una aplicación autenticadora. No compartas la clave mostrada.',
                  ),
                  const SizedBox(height: 16),
                  ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.string(
                        _svg(_enrollment!.qrCode),
                        width: 210,
                        height: 210,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _enrollment!.secret,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Código de verificación',
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      userFriendlyError(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : _cancel,
        child: const Text('Cerrar'),
      ),
      if (_enrollment != null)
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Verificando…' : 'Activar MFA'),
        ),
    ],
  );

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(
        () => _error = const AppException('Escribe un código de 6 dígitos.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyMfa(factorId: _enrollment!.factorId, code: _code.text);
      if (mounted) {
        ref.invalidate(verifiedTotpProvider);
        Navigator.pop(context);
        showOperationSuccess(context, 'MFA activado correctamente.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final enrollment = _enrollment;
    if (enrollment != null) {
      try {
        await ref.read(authRepositoryProvider).unenrollMfa(enrollment.factorId);
      } catch (_) {
        // Cerrar sigue siendo seguro; el factor aún no fue verificado.
      }
    }
    if (mounted) Navigator.pop(context);
  }
}
