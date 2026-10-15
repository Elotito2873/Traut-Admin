import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traut_admin/core/config/app_config.dart';
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
  Future<void> signOut() async {}

  @override
  Future<void> verifyMfa({
    required String factorId,
    required String code,
  }) async {
    verifyCalls++;
    gate = const MfaGate(MfaRequirement.none);
  }

  @override
  Future<String?> verifiedTotpFactorId() async => 'factor-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
}
