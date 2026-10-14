import '../entities/transport_entities.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

abstract interface class RouteGeometryService {
  Future<List<GeoPoint>> geometryForStops(List<RouteStop> orderedStops);
}

/// Geometría honesta para el esquema actual: une paradas, no calcula calles.
class StraightLineRouteGeometryService implements RouteGeometryService {
  const StraightLineRouteGeometryService();

  @override
  Future<List<GeoPoint>> geometryForStops(List<RouteStop> orderedStops) async =>
      orderedStops
          .map((stop) => GeoPoint(stop.latitude, stop.longitude))
          .toList(growable: false);
}
