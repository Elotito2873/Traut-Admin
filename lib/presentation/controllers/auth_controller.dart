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
  unauthorized,
}

class AuthViewState {
  const AuthViewState({
    required this.stage,
    this.profile,
    this.factorId,
    this.enrollment,
    this.error,
    this.busy = false,
  });

  const AuthViewState.initializing() : this(stage: AuthStage.initializing);

  final AuthStage stage;
  final AdminProfile? profile;
  final String? factorId;
  final MfaEnrollment? enrollment;
  final String? error;
  final bool busy;

  AuthViewState copyWith({
    bool? busy,
    String? error,
    MfaEnrollment? enrollment,
  }) {
    return AuthViewState(
      stage: stage,
      profile: profile,
      factorId: factorId,
      enrollment: enrollment ?? this.enrollment,
      error: error,
      busy: busy ?? this.busy,
    );
  }
}

class AuthController extends Notifier<AuthViewState> {
  StreamSubscription<AuthState>? _subscription;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthViewState build() {
    final client = ref.read(supabaseClientProvider);
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut &&
          state.stage != AuthStage.unauthorized) {
        state = const AuthViewState(stage: AuthStage.signedOut);
      }
    });
    ref.onDispose(() => _subscription?.cancel());
    Future<void>(_restore);
    return const AuthViewState.initializing();
  }

  Future<void> _restore() async {
    if (ref.read(supabaseClientProvider).auth.currentSession == null) {
      state = const AuthViewState(stage: AuthStage.signedOut);
      return;
    }
    await _authorize();
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthViewState(stage: AuthStage.signedOut, busy: true);
    try {
      await _repository.signIn(email, password);
      await _authorize();
    } catch (error) {
      state = AuthViewState(
        stage: AuthStage.signedOut,
        error: userFriendlyError(error),
      );
    }
  }

  Future<void> _authorize() async {
    state = const AuthViewState.initializing();
    try {
      AdminAccess access;
      try {
        access = await ref.read(authorizeAdminUseCaseProvider)(
          requireMfa: ref.read(appConfigProvider).requireAdminMfa,
        );
      } on AppException catch (error) {
        if (error.code != 'not_admin') rethrow;
        await _repository.signOut();
        state = const AuthViewState(
          stage: AuthStage.unauthorized,
          error: 'Tu cuenta no tiene permisos administrativos.',
        );
        return;
      }
      final profile = access.profile;
      final gate = access.mfaGate;
      state = switch (gate.requirement) {
        MfaRequirement.challenge => AuthViewState(
          stage: AuthStage.mfaChallenge,
          profile: profile,
          factorId: gate.factorId,
        ),
        MfaRequirement.enrollment => AuthViewState(
          stage: AuthStage.mfaEnrollment,
          profile: profile,
        ),
        MfaRequirement.none => AuthViewState(
          stage: AuthStage.authenticated,
          profile: profile,
        ),
      };
    } catch (error) {
      state = AuthViewState(
        stage: AuthStage.signedOut,
        error: userFriendlyError(error),
      );
    }
  }

  Future<void> beginEnrollment() async {
    if (state.enrollment != null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final enrollment = await _repository.enrollMfa();
      state = state.copyWith(busy: false, enrollment: enrollment);
    } catch (error) {
      state = state.copyWith(busy: false, error: userFriendlyError(error));
    }
  }

  Future<void> verifyMfa(String code) async {
    final factorId = state.factorId ?? state.enrollment?.factorId;
    if (factorId == null) return;
    state = state.copyWith(busy: true);
    try {
      await _repository.verifyMfa(factorId: factorId, code: code);
      state = AuthViewState(
        stage: AuthStage.authenticated,
        profile: state.profile,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: userFriendlyError(error));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthViewState(stage: AuthStage.signedOut);
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

  void returnToLogin() {
    state = const AuthViewState(stage: AuthStage.signedOut);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
);
