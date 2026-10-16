import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/transport_entities.dart';

const transportMapInteractionFlags =
    InteractiveFlag.drag |
    InteractiveFlag.flingAnimation |
    InteractiveFlag.pinchMove |
    InteractiveFlag.pinchZoom |
    InteractiveFlag.doubleTapZoom |
    InteractiveFlag.scrollWheelZoom;

class TransportMap extends StatefulWidget {
  const TransportMap({
    super.key,
    required this.config,
    this.vehicles = const [],
    this.stops = const [],
    this.routeColor = '#4F46E5',
    this.selectedVehicleId,
    this.onVehicleSelected,
    this.onStopSelected,
    this.onMapTap,
    this.mapController,
    this.interactive = true,
  });

  final AppConfig config;
  final List<Vehicle> vehicles;
  final List<RouteStop> stops;
  final String routeColor;
  final String? selectedVehicleId;
  final ValueChanged<Vehicle>? onVehicleSelected;
  final ValueChanged<RouteStop>? onStopSelected;
  final ValueChanged<LatLng>? onMapTap;
  final MapController? mapController;
  final bool interactive;

  @override
  State<TransportMap> createState() => _TransportMapState();
}

class _TransportMapState extends State<TransportMap> {
  late MapController _controller;
  late bool _ownsController;
  bool _ready = false;

  List<LatLng> get _points => [
    ...widget.vehicles
        .where((vehicle) => vehicle.location != null)
        .map(
          (vehicle) =>
              LatLng(vehicle.location!.latitude, vehicle.location!.longitude),
        ),
    ...widget.stops.map((stop) => LatLng(stop.latitude, stop.longitude)),
  ];

  @override
  void initState() {
    super.initState();
    _setController();
  }

  @override
  void didUpdateWidget(covariant TransportMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapController != widget.mapController) {
      if (_ownsController) _controller.dispose();
      _setController();
      _ready = false;
    }
  }

  void _setController() {
    _ownsController = widget.mapController == null;
    _controller = widget.mapController ?? MapController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final center = points.isEmpty
        ? const LatLng(19.4326, -99.1332)
        : points.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: MouseRegion(
        cursor: widget.interactive
            ? SystemMouseCursors.grab
            : MouseCursor.defer,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.isEmpty ? 5 : 13,
                initialCameraFit: points.isEmpty
                    ? null
                    : CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(52),
                        maxZoom: 15,
                        minZoom: 3,
                      ),
                minZoom: 3,
                maxZoom: 19,
                keepAlive: true,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? transportMapInteractionFlags
                      : InteractiveFlag.none,
                  scrollWheelVelocity: 0.0025,
                  cursorKeyboardRotationOptions:
                      CursorKeyboardRotationOptions.disabled(),
                ),
                onMapReady: () {
                  if (mounted) setState(() => _ready = true);
                },
                onTap: widget.onMapTap == null
                    ? null
                    : (_, position) => widget.onMapTap!(position),
              ),
              children: [
                TileLayer(
                  urlTemplate: widget.config.tileUrl,
                  userAgentPackageName: widget.config.osmUserAgent,
                ),
                if (widget.stops.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.stops
                            .map(
                              (stop) => LatLng(stop.latitude, stop.longitude),
                            )
                            .toList(),
                        strokeWidth: 5,
                        color: colorFromHex(widget.routeColor),
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers()),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (widget.interactive)
              Positioned(
                top: 12,
                right: 12,
                child: _MapControls(
                  enabled: _ready,
                  canFit: points.isNotEmpty,
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                  onFit: _fitPoints,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Marker> _markers() => [
    for (final stop in widget.stops)
      Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 44,
        height: 44,
        child: Tooltip(
          message: '${stop.order}. ${stop.name}',
          child: Semantics(
            button: widget.onStopSelected != null,
            label: 'Parada ${stop.name}',
            child: GestureDetector(
              onTap: widget.onStopSelected == null
                  ? null
                  : () => widget.onStopSelected!(stop),
              child: Icon(
                Icons.location_on,
                size: 34,
                color: colorFromHex(widget.routeColor),
              ),
            ),
          ),
        ),
      ),
    for (final vehicle in widget.vehicles)
      if (vehicle.location case final location?)
        Marker(
          point: LatLng(location.latitude, location.longitude),
          width: 52,
          height: 52,
          child: Tooltip(
            message: 'Unidad ${vehicle.code} · ${vehicle.status}',
            child: Semantics(
              button: widget.onVehicleSelected != null,
              label: 'Unidad ${vehicle.code}',
              child: GestureDetector(
                onTap: widget.onVehicleSelected == null
                    ? null
                    : () => widget.onVehicleSelected!(vehicle),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _vehicleColor(vehicle.status),
                    border: Border.all(
                      color: widget.selectedVehicleId == vehicle.id
                          ? Colors.white
                          : Colors.black26,
                      width: widget.selectedVehicleId == vehicle.id ? 4 : 2,
                    ),
                    boxShadow: const [
                      BoxShadow(blurRadius: 6, color: Colors.black38),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
  ];

  void _zoomBy(double amount) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + amount).clamp(3, 19));
  }

  void _fitPoints() {
    final points = _points;
    if (!_ready || points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(52),
        maxZoom: 15,
        minZoom: 3,
      ),
    );
  }

  Color _vehicleColor(String status) => switch (status) {
    'active' => Colors.green.shade700,
    'maintenance' => Colors.amber.shade800,
    'no_signal' => Colors.red.shade700,
    _ => Colors.blueGrey,
  };
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.enabled,
    required this.canFit,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final bool enabled;
  final bool canFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 3,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Acercar mapa',
          onPressed: enabled ? onZoomIn : null,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Alejar mapa',
          onPressed: enabled ? onZoomOut : null,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Mostrar todos los puntos',
          onPressed: enabled && canFit ? onFit : null,
          icon: const Icon(Icons.center_focus_strong),
        ),
      ],
    ),
  );
}
