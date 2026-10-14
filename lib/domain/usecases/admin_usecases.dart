import '../../core/errors/app_exception.dart';
import '../entities/admin_profile.dart';
import '../repositories/repositories.dart';

class AdminAccess {
  const AdminAccess({required this.profile, required this.mfaGate});
  final AdminProfile profile;
  final MfaGate mfaGate;
}

class AuthorizeAdminUseCase {
  const AuthorizeAdminUseCase(this._repository);
  final AuthRepository _repository;

  Future<AdminAccess> call({required bool requireMfa}) async {
    final profile = await _repository.currentAdmin();
    if (profile == null || !profile.isAdmin) {
      throw const AppException(
        'Tu cuenta no tiene permisos administrativos.',
        code: 'not_admin',
      );
    }
    final gate = await _repository.mfaRequirement(forceEnrollment: requireMfa);
    return AdminAccess(profile: profile, mfaGate: gate);
  }
}

class ChangeVehicleStatusUseCase {
  const ChangeVehicleStatusUseCase(this._repository);
  final VehicleRepository _repository;

  static const allowedStatuses = {
    'active',
    'inactive',
    'maintenance',
    'no_signal',
  };

  Future<void> call(String vehicleId, String status) {
    if (!allowedStatuses.contains(status)) {
      throw const AppException('El estado de la unidad no es válido.');
    }
    return _repository.updateVehicleStatus(vehicleId, status);
  }
}

class UpdateIncidentUseCase {
  const UpdateIncidentUseCase(this._repository);
  final IncidentRepository _repository;

  Future<void> call({
    required String incidentId,
    required String status,
    String? resolutionNotes,
  }) {
    if (!const {'open', 'reviewing', 'resolved'}.contains(status)) {
      throw const AppException('El estado de la incidencia no es válido.');
    }
    if (status == 'resolved' && (resolutionNotes?.trim().isEmpty ?? true)) {
      throw const AppException('Escribe una nota de resolución.');
    }
    return _repository.updateIncident(
      id: incidentId,
      status: status,
      resolutionNotes: resolutionNotes,
    );
  }
}
