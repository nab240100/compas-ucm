import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/widget_refresh.dart';
import '../../data/widget_snapshot.dart';
import '../../state/providers.dart';
import '../ajustes/ajustes_screen.dart';
import '../calendario/calendario_screen.dart';
import '../examenes/examenes_screen.dart';
import '../horario/horario_screen.dart';
import '../hoy/hoy_screen.dart';
import '../setup/wizard_screen.dart';

/// Carcasa principal. En el primer arranque (sin perfil) muestra el
/// asistente de configuración; después, las 5 pestañas.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  /// Última instantánea enviada al widget (evita reescribir en cada rebuild).
  String? _lastSnapshotJson;

  static const List<Widget> _screens = [
    HoyScreen(),
    HorarioScreen(),
    CalendarioScreen(),
    ExamenesScreen(),
    AjustesScreen(),
  ];

  /// Escribe la instantánea del widget de horario cuando cambia el perfil o
  /// se carga la app, y pide al widget que se redibuje.
  void _syncWidgetSnapshot(AcademicData? data, UserProfile? profile) {
    if (data == null || profile == null) return;
    final json = encodeWidgetSnapshot(data, profile);
    if (json == _lastSnapshotJson) return;
    _lastSnapshotJson = json;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(widgetSnapshotPrefsKey, json);
        await refreshWeekWidget();
      } catch (_) {
        // El widget es un extra: nunca debe romper la app.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final data = ref.watch(academicDataProvider).valueOrNull;
    final profile = profileAsync.valueOrNull;
    _syncWidgetSnapshot(data, profile);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('No se pudo cargar tu configuración.\n$e')),
      ),
      data: (UserProfile? value) => value == null
          ? const WizardScreen()
          : Scaffold(
              body: IndexedStack(index: _index, children: _screens),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (index) => setState(() => _index = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    selectedIcon: Icon(Icons.wb_sunny),
                    label: 'Hoy',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_view_week_outlined),
                    selectedIcon: Icon(Icons.calendar_view_week),
                    label: 'Horario',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendario',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Exámenes',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune),
                    label: 'Ajustes',
                  ),
                ],
              ),
            ),
    );
  }
}
