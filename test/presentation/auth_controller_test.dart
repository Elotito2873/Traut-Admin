import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/core/errors/app_exception.dart';
import 'package:traut_admin/domain/entities/admin_profile.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/presentation/controllers/auth_controller.dart';
import 'package:traut_admin/presentation/controllers/providers.dart';

class _MutableAuthRepository implements AuthRepository {
  AdminProfile? profile = const AdminProfile(
    id: 'admin-1',
    fullName: 'Admin',
    email: 'admin@example.com',
    role: 'admin',
  );
  MfaGate gate = const MfaGate(MfaRequirement.challenge, factorId: 'factor-1');
  int profileChecks = 0;
  int verifyCalls = 0;
  bool failSignOut = false;
  String? factorId = 'factor-1';
  final verifyErrors = Queue<Object>();
  Completer<void>? verifyBlock;

  @override
  Future<AdminProfile?> currentAdmin() async {
    profileChecks++;
    return profile;
  }

  @override
  Future<MfaGate> mfaRequirement({required bool forceEnrollment}) async => gate;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('network failure');
  }

  @override
  Future<void> verifyMfa({
    required String factorId,
    required String code,
  }) async {
    verifyCalls++;
    final block = verifyBlock;
    if (block != null) await block.future;
    if (verifyErrors.isNotEmpty) throw verifyErrors.removeFirst();
    gate = const MfaGate(MfaRequirement.none);
  }

  @override
  Future<String?> verifiedTotpFactorId() async => factorId;

  @override
  Future<MfaEnrollment> enrollMfa() async => const MfaEnrollment(
    factorId: 'new-factor',
    qrCode: '<svg/>',
    secret: 'secret',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('restaura sesión solo tras comprobar perfil admin', () async {
    final repository = _MutableAuthRepository()
      ..gate = const MfaGate(MfaRequirement.none);
    final supabase = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((_) async => throw StateError('Sin red en tests')),
    );
    await supabase.auth.recoverSession(
      jsonEncode({
        'access_token': 'token-prueba',
        'refresh_token': 'refresh-prueba',
        'token_type': 'bearer',
        'user': {
          'id': 'admin-1',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: 'https://project.supabase.co',
            supabasePublishableKey: 'sb_publishable_test',
            requireAdminMfa: true,
            tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            osmUserAgent: 'test',
          ),
        ),
        supabaseClientProvider.overrideWithValue(supabase),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repository.profileChecks, 1);
    expect(
      container.read(authControllerProvider).stage,
      AuthStage.authenticated,
    );

    repository.profile = const AdminProfile(
      id: 'admin-1',
      fullName: 'Revocado',
      email: 'admin@example.com',
      role: 'user',
    );
    await container.read(authControllerProvider.notifier).revalidateOnResume();
    expect(
      container.read(authControllerProvider).stage,
      AuthStage.unauthorized,
    );
  });

  test(
    'admin sin TOTP entra a enrolamiento y lock exige factor válido',
    () async {
      final repository = _MutableAuthRepository()
        ..gate = const MfaGate(MfaRequirement.enrollment);
      final supabase = SupabaseClient(
        'https://project.supabase.co',
        'sb_publishable_test',
        httpClient: MockClient(
          (_) async => throw StateError('Sin red en tests'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://project.supabase.co',
              supabasePublishableKey: 'sb_publishable_test',
              requireAdminMfa: true,
              tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              osmUserAgent: 'test',
            ),
          ),
          supabaseClientProvider.overrideWithValue(supabase),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn('admin@example.com', 'password');
      expect(
        container.read(authControllerProvider).stage,
        AuthStage.mfaEnrollment,
      );
      await controller.beginEnrollment();
      expect(
        container.read(authControllerProvider).enrollment?.factorId,
        'new-factor',
      );
      await controller.verifyMfa('123456');
      expect(
        container.read(authControllerProvider).stage,
        AuthStage.authenticated,
      );
      await controller.lockForInactivity();
      expect(container.read(authControllerProvider).stage, AuthStage.locked);
      await controller.verifyMfa('123456');
      expect(
        container.read(authControllerProvider).stage,
        AuthStage.authenticated,
      );
    },
  );

  test(
    'MFA vuelve a autorizar y rechaza un rol cambiado durante el challenge',
    () async {
      final repository = _MutableAuthRepository();
      final supabase = SupabaseClient(
        'https://project.supabase.co',
        'sb_publishable_test',
        httpClient: MockClient(
          (_) async => throw StateError('Sin red en tests'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://project.supabase.co',
              supabasePublishableKey: 'sb_publishable_test',
              requireAdminMfa: true,
              tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              osmUserAgent: 'test',
            ),
          ),
          supabaseClientProvider.overrideWithValue(supabase),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.signIn('admin@example.com', 'not-stored');
      expect(
        container.read(authControllerProvider).stage,
        AuthStage.mfaChallenge,
      );

      repository.profile = const AdminProfile(
        id: 'admin-1',
        fullName: 'Former admin',
        email: 'admin@example.com',
        role: 'driver',
      );
      await controller.verifyMfa('123456');

      expect(repository.verifyCalls, 1);
      expect(repository.profileChecks, 2);
      expect(
        container.read(authControllerProvider).stage,
        AuthStage.unauthorized,
      );
    },
  );

  test('logout limpia el estado aunque falle la llamada de red', () async {
    final repository = _MutableAuthRepository()..failSignOut = true;
    final supabase = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((_) async => throw StateError('Sin red en tests')),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: 'https://project.supabase.co',
            supabasePublishableKey: 'sb_publishable_test',
            requireAdminMfa: false,
            tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            osmUserAgent: 'test',
          ),
        ),
        supabaseClientProvider.overrideWithValue(supabase),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);
    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider).stage, AuthStage.signedOut);
  });

  for (final errorCode in [
    'mfa_verification_failed',
    'mfa_challenge_expired',
  ]) {
    test('MFA recupera un segundo intento después de $errorCode', () async {
      final repository = _MutableAuthRepository()
        ..verifyErrors.add(
          AppException(
            'Usa el código actual de tu autenticador e inténtalo nuevamente.',
            code: errorCode,
          ),
        );
      final container = _mfaContainer(repository);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(authControllerProvider.notifier);

      await controller.signIn('admin@example.com', 'password');
      await controller.verifyMfa('000000');

      var state = container.read(authControllerProvider);
      expect(state.stage, AuthStage.mfaChallenge);
      expect(state.errorCode, errorCode);
      expect(
        state.error,
        'Usa el código actual de tu autenticador e inténtalo nuevamente.',
      );

      await controller.verifyMfa('123456');
      state = container.read(authControllerProvider);
      expect(state.stage, AuthStage.authenticated);
      expect(repository.verifyCalls, 2);
    });
  }

  test('MFA permite reintentar después de timeout sin cerrar sesión', () async {
    final repository = _MutableAuthRepository()
      ..verifyErrors.add(
        const AppException(
          'La verificación tardó demasiado.',
          code: 'mfa_timeout',
        ),
      );
    final container = _mfaContainer(repository);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(authControllerProvider.notifier);

    await controller.signIn('admin@example.com', 'password');
    await controller.verifyMfa('000000');

    expect(
      container.read(authControllerProvider).stage,
      AuthStage.mfaChallenge,
    );
    expect(container.read(authControllerProvider).errorCode, 'mfa_timeout');

    await controller.verifyMfa('123456');
    expect(
      container.read(authControllerProvider).stage,
      AuthStage.authenticated,
    );
    expect(repository.verifyCalls, 2);
  });

  test('MFA ignora doble envío mientras hay una verificación activa', () async {
    final block = Completer<void>();
    final repository = _MutableAuthRepository()..verifyBlock = block;
    final container = _mfaContainer(repository);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(authControllerProvider.notifier);

    await controller.signIn('admin@example.com', 'password');
    final first = controller.verifyMfa('123456');
    await controller.verifyMfa('123456');
    expect(repository.verifyCalls, 1);

    block.complete();
    await first;
    expect(
      container.read(authControllerProvider).stage,
      AuthStage.authenticated,
    );
  });

  test('MFA cierra el acceso cuando la sesión ya no existe', () async {
    final repository = _MutableAuthRepository()
      ..verifyErrors.add(
        const AppException(
          'Tu sesión terminó. Inicia sesión nuevamente.',
          code: 'session_not_found',
        ),
      );
    final container = _mfaContainer(repository);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(authControllerProvider.notifier);

    await controller.signIn('admin@example.com', 'password');
    await controller.verifyMfa('123456');

    expect(container.read(authControllerProvider).stage, AuthStage.signedOut);
    expect(
      container.read(authControllerProvider).error,
      'Tu sesión terminó. Inicia sesión nuevamente.',
    );
  });
}

ProviderContainer _mfaContainer(_MutableAuthRepository repository) {
  final supabase = SupabaseClient(
    'https://project.supabase.co',
    'sb_publishable_test',
    httpClient: MockClient((_) async => throw StateError('Sin red en tests')),
  );
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          supabaseUrl: 'https://project.supabase.co',
          supabasePublishableKey: 'sb_publishable_test',
          requireAdminMfa: true,
          tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          osmUserAgent: 'test',
        ),
      ),
      supabaseClientProvider.overrideWithValue(supabase),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}
