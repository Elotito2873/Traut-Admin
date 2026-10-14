import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/errors/app_exception.dart';
import 'package:traut_admin/domain/entities/admin_profile.dart';
import 'package:traut_admin/domain/repositories/repositories.dart';
import 'package:traut_admin/domain/usecases/admin_usecases.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.profile, this.gate);
  final AdminProfile? profile;
  final MfaGate gate;

  @override
  Future<AdminProfile?> currentAdmin() async => profile;

  @override
  Future<MfaGate> mfaRequirement({required bool forceEnrollment}) async => gate;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('AuthorizeAdminUseCase rechaza roles no administrativos', () async {
    final repository = _FakeAuthRepository(
      const AdminProfile(
        id: 'user-1',
        fullName: 'Usuario',
        email: 'user@example.com',
        role: 'user',
      ),
      const MfaGate(MfaRequirement.none),
    );

    expect(
      () => AuthorizeAdminUseCase(repository)(requireMfa: true),
      throwsA(isA<AppException>()),
    );
  });

  test('AuthorizeAdminUseCase conserva el gate MFA', () async {
    final repository = _FakeAuthRepository(
      const AdminProfile(
        id: 'admin-1',
        fullName: 'Admin',
        email: 'admin@example.com',
        role: 'admin',
      ),
      const MfaGate(MfaRequirement.challenge, factorId: 'factor-1'),
    );

    final result = await AuthorizeAdminUseCase(repository)(requireMfa: true);
    expect(result.profile.isAdmin, isTrue);
    expect(result.mfaGate.factorId, 'factor-1');
  });
}
