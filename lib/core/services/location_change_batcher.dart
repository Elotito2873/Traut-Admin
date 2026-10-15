import 'dart:async';

/// Agrupa IDs recibidos por Realtime para evitar una consulta por cada punto
/// GPS. La capa de datos conserva un solo canal y emite un lote por ventana.
class LocationChangeBatcher {
  LocationChangeBatcher({required this.window, required this.onBatch});

  final Duration window;
  final void Function(Set<String> vehicleIds) onBatch;
  final Set<String> _pending = {};
  Timer? _timer;

  void add(String vehicleId) {
    if (vehicleId.isEmpty) return;
    _pending.add(vehicleId);
    _timer ??= Timer(window, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = Set<String>.unmodifiable(_pending);
    _pending.clear();
    onBatch(batch);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
