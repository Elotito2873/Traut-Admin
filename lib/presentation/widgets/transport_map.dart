import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/transport_entities.dart';

class TransportMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final points = [
      ...vehicles
          .where((vehicle) => vehicle.location != null)
          .map(
            (vehicle) =>
                LatLng(vehicle.location!.latitude, vehicle.location!.longitude),
          ),
      ...stops.map((stop) => LatLng(stop.latitude, stop.longitude)),
    ];
    final center = points.isEmpty
        ? const LatLng(19.4326, -99.1332)
        : points.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: points.isEmpty ? 5 : 13,
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
          onTap: onMapTap == null ? null : (_, position) => onMapTap!(position),
        ),
        children: [
          TileLayer(
            urlTemplate: config.tileUrl,
            userAgentPackageName: config.osmUserAgent,
          ),
          if (stops.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: stops
                      .map((stop) => LatLng(stop.latitude, stop.longitude))
                      .toList(),
                  strokeWidth: 5,
                  color: colorFromHex(routeColor),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final stop in stops)
                Marker(
                  point: LatLng(stop.latitude, stop.longitude),
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: '${stop.order}. ${stop.name}',
                    child: Semantics(
                      button: onStopSelected != null,
                      label: 'Parada ${stop.name}',
                      child: GestureDetector(
                        onTap: onStopSelected == null
                            ? null
                            : () => onStopSelected!(stop),
                        child: Icon(
                          Icons.location_on,
                          size: 34,
                          color: colorFromHex(routeColor),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final vehicle in vehicles)
                if (vehicle.location case final location?)
                  Marker(
                    point: LatLng(location.latitude, location.longitude),
                    width: 52,
                    height: 52,
                    child: Tooltip(
                      message: 'Unidad ${vehicle.code} · ${vehicle.status}',
                      child: Semantics(
                        button: onVehicleSelected != null,
                        label: 'Unidad ${vehicle.code}',
                        child: GestureDetector(
                          onTap: onVehicleSelected == null
                              ? null
                              : () => onVehicleSelected!(vehicle),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _vehicleColor(vehicle.status),
                              border: Border.all(
                                color: selectedVehicleId == vehicle.id
                                    ? Colors.white
                                    : Colors.black26,
                                width: selectedVehicleId == vehicle.id ? 4 : 2,
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
            ],
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
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
