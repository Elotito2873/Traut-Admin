import 'package:flutter/material.dart';

Color colorFromHex(String value, {Color fallback = const Color(0xFF4F46E5)}) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null || normalized.length != 6) return fallback;
  return Color(0xFF000000 | parsed);
}
