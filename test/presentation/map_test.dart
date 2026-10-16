import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traut_admin/core/config/app_config.dart';
import 'package:traut_admin/domain/entities/transport_entities.dart';
import 'package:traut_admin/presentation/widgets/transport_map.dart';

void main() {
  testWidgets('mapa habilita pan y rueda sin rotación accidental', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    final vehicle = Vehicle(
      id: 'vehicle-1',
      code: 'U-01',
      plate: 'ABC-001',
      status: 'active',
      createdAt: DateTime.utc(2026),
      location: VehicleLocation(
        latitude: 19.4326,
        longitude: -99.1332,
        speed: 20,
        heading: 0,
        updatedAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 500,
            child: TransportMap(
              config: _config,
              vehicles: [vehicle],
              mapController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final flags = map.options.interactionOptions.flags;
    expect(InteractiveFlag.hasDrag(flags), isTrue);
    expect(InteractiveFlag.hasScrollWheelZoom(flags), isTrue);
    expect(InteractiveFlag.hasPinchMove(flags), isTrue);
    expect(InteractiveFlag.hasRotate(flags), isFalse);
    expect(map.options.initialCameraFit, isNotNull);
    expect(find.byTooltip('Mostrar todos los puntos'), findsOneWidget);

    final mapCenter = tester.getCenter(find.byType(FlutterMap));
    final longitudeBeforeDrag = controller.camera.center.longitude;
    await tester.dragFrom(
      mapCenter + const Offset(-180, 120),
      const Offset(90, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.camera.center.longitude, isNot(longitudeBeforeDrag));

    final zoomBeforeWheel = controller.camera.zoom;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: mapCenter,
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.camera.zoom, greaterThan(zoomBeforeWheel));

    final cameraAfterOperatorMovement = controller.camera.center;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 500,
            child: TransportMap(
              config: _config,
              vehicles: [
                Vehicle(
                  id: vehicle.id,
                  code: vehicle.code,
                  plate: vehicle.plate,
                  status: vehicle.status,
                  createdAt: vehicle.createdAt,
                  location: VehicleLocation(
                    latitude: 19.45,
                    longitude: -99.15,
                    speed: 24,
                    heading: 0,
                    updatedAt: DateTime.utc(2026, 10),
                  ),
                ),
              ],
              mapController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.camera.center, cameraAfterOperatorMovement);
  });
}

const _config = AppConfig(
  supabaseUrl: 'https://project.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  requireAdminMfa: false,
  tileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
  osmUserAgent: 'test',
);
