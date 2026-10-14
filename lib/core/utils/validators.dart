class Validators {
  const Validators._();

  static String? requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label es obligatorio.';
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, 'El correo');
    if (required != null) return required;
    final expression = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return expression.hasMatch(value!.trim())
        ? null
        : 'Escribe un correo válido.';
  }

  static String? coordinate(String? value, {required bool latitude}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Escribe un número válido.';
    final limit = latitude ? 90.0 : 180.0;
    if (parsed < -limit || parsed > limit) {
      return latitude
          ? 'La latitud debe estar entre -90 y 90.'
          : 'La longitud debe estar entre -180 y 180.';
    }
    return null;
  }

  static String? money(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Escribe un importe válido.';
    return null;
  }

  static String? hexColor(String? value) {
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Usa el formato #RRGGBB.';
  }
}
