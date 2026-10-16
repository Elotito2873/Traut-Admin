import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/admin_profile.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/admin_usecases.dart';
import 'providers.dart';

enum AuthStage {
  initializing,
  signedOut,
  mfaChallenge,
  mfaEnrollment,
  authenticated,
  locked,
  unauthorized,
}

class AuthViewState {
  const AuthViewState({
    required this.stage,
    this.profile,
    this.factorId,
    this.enrollment,
    this.error,
    this.errorCode,
    this.busy = false,
    this.checkingAccess = false,
  });

  const AuthViewState.initializing() : this(stage: AuthStage.initializing);

  final AuthStage stage;
  final AdminProfile? profile;
  final String? factorId;
  final MfaEnrollment? enrollment;
  final String? error;
  final String? errorCode;
  final bool busy;
  final bool checkingAccess;

  AuthViewState copyWith({
    bool? busy,
    String? error,
    String? errorCode,
    bool clearError = false,
    MfaEnrollment? enrollment,
    bool? checkingAccess,
  }) {
    return AuthViewState(
      stage: stage,
      profile: profile,
      factorId: factorId,
      enrollment: enrollment ?? this.enrollment,
      error: clearError ? null : error ?? this.error,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      busy: busy ?? this.busy,
      checkingAccess: checkingAccess ?? this.checkingAccess,
    );
  }
}

class AuthController extends Notifier<AuthViewState> {
  StreamSubscription<AuthState>? _subscription;
  bool _revalidating = false;
  int _generation = 0;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthViewState build() {
    final client = ref.read(supabaseClientProvider);
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut &&
          state.stage != AuthStage.unauthorized) {
        _generation++;
        _clearAdministrativeData();
        state = const AuthViewState(stage: AuthStage.signedOut);
      } else if ((event.event == AuthChangeEvent.tokenRefreshed ||
              event.event == AuthChangeEvent.userUpdated) &&
          (state.stage == AuthStage.authenticated ||
              state.stage == AuthStage.locked)) {
        unawaited(_revalidateAccess());
      }
    });
    ref.onDispose(() => _subscription?.cancel());
    Future<void>(_restore);
    return const AuthViewState.initializing();
  }

  Future<void> _restore() async {
    if (!ref.mounted) return;
    final generation = _generation;
    if (ref.read(supabaseClientProvider).auth.currentSession == null) {
      if (ref.mounted && generation == _generation) {
        state = const AuthViewState(stage: AuthStage.signedOut);
      }
      return;
    }
    await _authorize();
  }

  Future<void> signIn(String email, String password) async {
    final generation = ++_generation;
    state = const AuthViewState(stage: AuthStage.signedOut, busy: true);
    try {
      await _repository.signIn(email, password);
      if (!ref.mounted || generation != _generation) return;
      await _authorize();
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = const AuthViewState(stage: AuthStage.unauthorized);
      try {
        await _repository.signOut();
      } catch (_) {
        // El estado local se cierra aunque falle la revocación remota.
      }
      if (!ref.mounted || generation != _generation) return;
      _clearAdministrativeData();
      state = _afterSignOut(error: userFriendlyError(error));
    }
  }

  Future<void> _revalidateAccess() async {
    if (_revalidating) return;
    if (ref.read(supabaseClientProvider).auth.currentSession == null) {
      _clearAdministrativeData();
      state = const AuthViewState(stage: AuthStage.signedOut);
      return;
    }
    _revalidating = true;
    final keepLock = state.stage == AuthStage.locked;
    state = state.copyWith(checkingAccess: true);
    try {
      await _authorize(preserveAdministrativeShell: true, keepLock: keepLock);
    } finally {
      _revalidating = false;
    }
  }

  Future<void> revalidateOnResume() async {
    if (state.stage == AuthStage.authenticated ||
        state.stage == AuthStage.locked) {
      await _revalidateAccess();
    }
  }

  Future<void> _authorize({
    bool preserveAdministrativeShell = false,
    bool keepLock = false,
  }) async {
    final generation = _generation;
    if (!preserveAdministrativeShell) {
      state = const AuthViewState.initializing();
    }
    try {
      AdminAccess access;
      try {
        if (!ref.read(appConfigProvider).requireAdminMfa) {
          throw const AppException(
            'La configuración administrativa debe exigir MFA.',
            code: 'invalid_config',
          );
        }
        access = await ref.read(authorizeAdminUseCaseProvider)(
          requireMfa: true,
        );
        if (!ref.mounted || generation != _generation) return;
      } on AppException catch (error) {
        if (!ref.mounted || generation != _generation) return;
        if (error.code != 'not_admin') rethrow;
        _clearAdministrativeData();
        state = const AuthViewState(
          stage: AuthStage.unauthorized,
          error: 'Tu cuenta no tiene permisos administrativos.',
        );
        try {
          await _repository.signOut();
        } catch (_) {
          // La autorización falla cerrada aunque la red no responda.
        }
        if (!ref.mounted || generation != _generation) return;
        return;
      }
      final profile = access.profile;
      final gate = access.mfaGate;
      state = switch (gate.requirement) {
        MfaRequirement.challenge => AuthViewState(
          stage: preserveAdministrativeShell
              ? AuthStage.locked
              : AuthStage.mfaChallenge,
          profile: profile,
          factorId: gate.factorId,
        ),
        MfaRequirement.enrollment => AuthViewState(
          stage: AuthStage.mfaEnrollment,
          profile: profile,
        ),
        MfaRequirement.none => AuthViewState(
          stage: keepLock ? AuthStage.locked : AuthStage.authenticated,
          profile: profile,
          factorId: keepLock ? state.factorId : null,
        ),
      };
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = const AuthViewState(stage: AuthStage.unauthorized);
      try {
        await _repository.signOut();
      } catch (_) {
        // Se bloquea el acceso local incluso si la red falla.
      }
      if (!ref.mounted || generation != _generation) return;
      _clearAdministrativeData();
      state = _afterSignOut(error: userFriendlyError(error));
    }
  }

  Future<void> beginEnrollment() async {
    if (state.enrollment != null || state.busy) return;
    final generation = _generation;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final enrollment = await _repository.enrollMfa();
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(busy: false, enrollment: enrollment);
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(busy: false, error: userFriendlyError(error));
    }
  }

  Future<void> verifyMfa(String code) async {
    final factorId = state.factorId ?? state.enrollment?.factorId;
    if (factorId == null || state.busy) return;
    final preserveAdministrativeShell = state.stage == AuthStage.locked;
    state = state.copyWith(busy: true, clearError: true);
    final generation = _generation;
    try {
      await _repository.verifyMfa(factorId: factorId, code: code);
      if (!ref.mounted || generation != _generation) return;
      await _authorize(
        preserveAdministrativeShell: preserveAdministrativeShell,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      final code = error is AppException ? error.code : null;
      if (isLostMfaSessionErrorCode(code)) {
        state = AuthViewState(
          stage: AuthStage.unauthorized,
          error: userFriendlyError(error),
          errorCode: code,
        );
        try {
          await _repository.signOut();
        } catch (_) {
          // La sesión ya no es utilizable y el acceso local queda cerrado.
        }
        if (!ref.mounted || generation != _generation) return;
        _clearAdministrativeData();
        state = _afterSignOut(error: userFriendlyError(error));
        return;
      }
      state = state.copyWith(
        busy: false,
        error: userFriendlyError(error),
        errorCode: code,
      );
    }
  }

  Future<void> lockForInactivity() async {
    if (state.stage != AuthStage.authenticated) return;
    final generation = _generation;
    final profile = state.profile;
    try {
      final factorId = await _repository.verifiedTotpFactorId();
      if (!ref.mounted || generation != _generation) return;
      if (factorId == null) {
        state = const AuthViewState(stage: AuthStage.unauthorized);
        try {
          await _repository.signOut();
        } catch (_) {
          // La sesión local ya no se considera válida en la aplicación.
        }
        if (!ref.mounted || generation != _generation) return;
        _clearAdministrativeData();
        state = _afterSignOut(
          error:
              'La sesión se cerró por inactividad. Inicia sesión nuevamente.',
        );
        return;
      }
      state = AuthViewState(
        stage: AuthStage.locked,
        profile: profile,
        factorId: factorId,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = const AuthViewState(stage: AuthStage.unauthorized);
      try {
        await _repository.signOut();
      } catch (_) {
        // Se continúa con la limpieza local.
      }
      if (!ref.mounted || generation != _generation) return;
      _clearAdministrativeData();
      state = _afterSignOut(error: userFriendlyError(error));
    }
  }

  Future<void> signOut() async {
    final generation = ++_generation;
    try {
      await _repository.signOut();
    } catch (_) {
      // Supabase elimina primero la sesión local con SignOutScope.local.
    } finally {
      if (ref.mounted && generation == _generation) {
        _clearAdministrativeData();
        state = _afterSignOut();
      }
    }
  }

  Future<void> cancelMfaAndSignOut() async {
    final unverifiedFactorId = state.enrollment?.factorId;
    if (unverifiedFactorId != null) {
      try {
        await _repository.unenrollMfa(unverifiedFactorId);
      } catch (_) {
        // La sesión se cierra aunque Supabase ya haya descartado el factor.
      }
    }
    await signOut();
  }

  Future<void> returnToLogin() => signOut();

  AuthViewState _afterSignOut({String? error}) {
    if (!ref.mounted) return const AuthViewState(stage: AuthStage.signedOut);
    if (ref.read(supabaseClientProvider).auth.currentSession != null) {
      return const AuthViewState(
        stage: AuthStage.unauthorized,
        error:
            'El cierre local no se completó. Intenta cerrar sesión otra vez.',
      );
    }
    return AuthViewState(stage: AuthStage.signedOut, error: error);
  }

  void _clearAdministrativeData() {
    if (!ref.mounted) return;
    ref.invalidate(dashboardProvider);
    ref.invalidate(monitoredVehiclesProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(routesProvider);
    ref.invalidate(routeProvider);
    ref.invalidate(driversProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(tripsProvider);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
);
