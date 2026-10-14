import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/providers.dart';
import 'global_search_field.dart';

class _NavigationItem {
  const _NavigationItem(this.label, this.location, this.icon);
  final String label;
  final String location;
  final IconData icon;
}

const _items = [
  _NavigationItem('Resumen', '/', Icons.dashboard_outlined),
  _NavigationItem('Monitoreo', '/monitoring', Icons.map_outlined),
  _NavigationItem('Flota', '/fleet', Icons.directions_bus_outlined),
  _NavigationItem('Rutas', '/routes', Icons.alt_route),
  _NavigationItem('Conductores', '/drivers', Icons.badge_outlined),
  _NavigationItem('Viajes', '/trips', Icons.route_outlined),
  _NavigationItem('Incidencias', '/incidents', Icons.warning_amber_outlined),
  _NavigationItem('Configuración', '/settings', Icons.settings_outlined),
];

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    ref.read(preferencesProvider).loadSidebarExpanded().then((value) {
      if (mounted) setState(() => _expanded = value);
    });
  }

  int _selectedIndex(String path) {
    if (path.startsWith('/monitoring')) return 1;
    if (path.startsWith('/fleet')) return 2;
    if (path.startsWith('/routes')) return 3;
    if (path.startsWith('/drivers')) return 4;
    if (path.startsWith('/trips')) return 5;
    if (path.startsWith('/incidents')) return 6;
    if (path.startsWith('/settings')) return 7;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(path);
    final title = _items[selected].label;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final searchVisible = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      drawer: wide
          ? null
          : Drawer(
              width: 290,
              child: SafeArea(
                child: _Sidebar(
                  expanded: true,
                  selected: selected,
                  onSelect: (index) {
                    Navigator.pop(context);
                    context.go(_items[index].location);
                  },
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              _Sidebar(
                expanded: _expanded,
                selected: selected,
                onSelect: (index) => context.go(_items[index].location),
                onToggle: () {
                  setState(() => _expanded = !_expanded);
                  ref.read(preferencesProvider).saveSidebarExpanded(_expanded);
                },
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 78),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Abrir navegación',
                              onPressed: Scaffold.of(context).openDrawer,
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (searchVisible) const GlobalSearchField(),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Cambiar tema',
                          onPressed: () {
                            final current = ref.read(themeModeProvider);
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(
                                  current == ThemeMode.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark,
                                );
                          },
                          icon: const Icon(Icons.contrast),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.expanded,
    required this.selected,
    required this.onSelect,
    this.onToggle,
  });

  final bool expanded;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final width = expanded ? 264.0 : 82.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 86,
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const SizedBox(width: 18),
                Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Traut',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('Panel administrativo'),
                      ],
                    ),
                  ),
                ],
                if (onToggle != null && expanded)
                  IconButton(
                    tooltip: 'Contraer barra lateral',
                    onPressed: onToggle,
                    icon: const Icon(Icons.chevron_left),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Tooltip(
                    message: expanded ? '' : item.label,
                    child: ListTile(
                      minTileHeight: 50,
                      selected: selected == index,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: expanded ? 14 : 18,
                      ),
                      leading: Icon(item.icon),
                      title: expanded ? Text(item.label) : null,
                      onTap: () => onSelect(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: expanded
                ? Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName[0]
                                    : 'A')
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(
                          profile?.fullName ?? 'Administrador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          profile?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: ref
                              .read(authControllerProvider.notifier)
                              .signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar sesión'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      IconButton(
                        tooltip: 'Expandir barra lateral',
                        onPressed: onToggle,
                        icon: const Icon(Icons.chevron_right),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: ref
                            .read(authControllerProvider.notifier)
                            .signOut,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
