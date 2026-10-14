import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('acepta coordenadas en los límites', () {
      expect(Validators.coordinate('90', latitude: true), isNull);
      expect(Validators.coordinate('-180', latitude: false), isNull);
    });

    test('rechaza coordenadas imposibles', () {
      expect(Validators.coordinate('91', latitude: true), isNotNull);
      expect(Validators.coordinate('-181', latitude: false), isNotNull);
    });

    test('rechaza tarifas negativas y colores inválidos', () {
      expect(Validators.money('-1'), isNotNull);
      expect(Validators.hexColor('#4F46E5'), isNull);
      expect(Validators.hexColor('violeta'), isNotNull);
    });
  });
}
