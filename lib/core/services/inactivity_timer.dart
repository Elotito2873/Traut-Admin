import 'dart:async';

/// Temporizador independiente de la UI para poder probar el lock sin esperar
/// minutos ni depender de una plataforma concreta.
class InactivityTimer {
  InactivityTimer({required this.timeout, required this.onTimeout});

  final Duration timeout;
  final void Function() onTimeout;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer(timeout, onTimeout);
  }

  void registerActivity() => start();

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
