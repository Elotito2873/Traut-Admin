import 'dart:async';

class AppException implements Exception {
  const AppException(this.userMessage, {this.code, this.cause});

  final String userMessage;
  final String? code;
  final Object? cause;

  @override
  String toString() => userMessage;
}

const retryableMfaErrorCodes = {
  'mfa_verification_failed',
  'mfa_challenge_expired',
  'mfa_timeout',
};

const lostMfaSessionErrorCodes = {
  'session_expired',
  'session_not_found',
  'no_authorization',
};

bool isRetryableMfaErrorCode(String? code) =>
    retryableMfaErrorCodes.contains(code);

bool isLostMfaSessionErrorCode(String? code) =>
    lostMfaSessionErrorCodes.contains(code);

String userFriendlyError(Object error) {
  if (error is AppException) return error.userMessage;
  if (error is TimeoutException) {
    return 'La conexión agotó el tiempo. Comprueba si la operación se aplicó antes de reintentar.';
  }
  return 'No fue posible completar la operación. Revisa tu conexión e intenta de nuevo.';
}
