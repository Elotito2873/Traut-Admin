class AppException implements Exception {
  const AppException(this.userMessage, {this.code, this.cause});

  final String userMessage;
  final String? code;
  final Object? cause;

  @override
  String toString() => userMessage;
}

String userFriendlyError(Object error) {
  if (error is AppException) return error.userMessage;
  return 'No fue posible completar la operación. Revisa tu conexión e intenta de nuevo.';
}
