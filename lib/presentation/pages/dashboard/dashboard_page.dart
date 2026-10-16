import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/transport_entities.dart';
import '../../controllers/providers.dart';
import '../../widgets/common_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(dashboardProvider.future);
      },
      child: ListView(
        padding: responsivePagePadding(context),
        children: [
          const PageIntro(
            title: 'Resumen operativo',
            subtitle:
                'Indicadores actuales de la red. Todos los valores provienen de Supabase.',
          ),
          const SizedBox(height: 24),
          metrics.when(
            loading: () => const SizedBox(height: 180, child: LoadingPanel()),
            error: (error, _) => SizedBox(
              height: 220,
              child: ErrorPanel(
                error: error,
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
            ),
            data: (data) => _MetricsGrid(metrics: data),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 420
                          ? constraints.maxWidth
                          : 390,
                      child: const Row(
                        children: [
                          Icon(Icons.map_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El mapa GPS en vivo está en Monitoreo.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/monitoring'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir monitoreo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Unidades totales', metrics.totalVehicles, Icons.directions_bus, null),
      (
        'Unidades activas',
        metrics.activeVehicles,
        Icons.check_circle,
        Colors.green,
      ),
      (
        'En mantenimiento',
        metrics.maintenanceVehicles,
        Icons.build_circle,
        Colors.amber.shade800,
      ),
      (
        'Sin señal',
        metrics.noSignalVehicles,
        Icons.signal_wifi_off,
        Colors.red,
      ),
      ('Rutas activas', metrics.activeRoutes, Icons.alt_route, null),
      ('Conductores activos', metrics.activeDrivers, Icons.badge, null),
      ('Viajes activos', metrics.activeTrips, Icons.route, null),
      (
        'Incidencias pendientes',
        metrics.openIncidents,
        Icons.warning_amber,
        metrics.openIncidents > 0 ? Colors.red : Colors.green,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              (card.$4 ?? Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.15),
                          foregroundColor:
                              card.$4 ?? Theme.of(context).colorScheme.primary,
                          child: Icon(card.$3),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.$1),
                              Text(
                                card.$2.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
