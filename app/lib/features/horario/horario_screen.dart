import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/course_palette.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/projection.dart';
import '../../state/providers.dart';
import '../setup/wizard_screen.dart';

/// Franja horaria que ocupa el grid (08:00 → 20:30).
const int _firstMinute = 8 * 60; // 08:00
const int _lastMinute = 20 * 60 + 30; // 20:30
const double _gutterWidth = 56;
const double _dayHeaderHeight = 42;

/// Mínimos de legibilidad: si el espacio disponible no llega a estos valores,
/// el contenido crece y la vista recupera el desplazamiento (scroll).
const double _minHourHeight = 26;
const double _minColWidth = 56;

/// Desplazamiento horizontal de cada tarjeta cuando hay clases solapadas.
const double _overlapStep = 14;

// ------------------------------------------------------------------ eventos

/// Color del marcador de un evento (mismos códigos que en la pestaña
/// Calendario: festivo miel, no lectivo salvia, vacaciones crema…).
Color _markerColorOf(EventType t) => switch (t) {
      EventType.festivo => const Color(0xFFB98A2F),
      EventType.noLectivo => const Color(0xFF6F7D5C),
      EventType.vacaciones => const Color(0xFF9A8B7A),
      EventType.welcome => const Color(0xFFB85C38),
      EventType.recovery => const Color(0xFF6F5FA8),
      EventType.otro => const Color(0xFFB98A2F),
    };

/// Color de texto legible sobre la pastilla del marcador.
Color _markerTextColorOf(EventType t) =>
    (t == EventType.festivo || t == EventType.vacaciones)
        ? const Color(0xFF241703)
        : Colors.white;

/// Etiqueta compacta del marcador (igual que en Calendario).
String _eventChipLabel(CalendarEvent e) => switch (e.name) {
      'Acto de bienvenida' => 'Bienvenida',
      'Día de recuperación' => 'Recup.',
      _ => e.name,
    };

/// ¿El evento se lleva el día entero (no hay clases)? Festivos, no lectivos
/// y vacaciones; welcome/recuperación solo muestran el marcador.
bool _isNoClassDay(CalendarEvent e) =>
    e.type == EventType.festivo ||
    e.type == EventType.noLectivo ||
    e.type == EventType.vacaciones;

/// Horario semanal personalizado: proyección de (curso, asignaturas, turnos).
class HorarioScreen extends ConsumerStatefulWidget {
  const HorarioScreen({super.key});

  @override
  ConsumerState<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends ConsumerState<HorarioScreen> {
  int? _semesterOverride;
  int _weekOffset = 0;
  bool _showTheory = true;
  bool _showLabs = true;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(academicDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario'),
        actions: [
          IconButton(
            tooltip: 'Editar asignaturas',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WizardScreen(editMode: true)),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los datos.\n$e')),
        data: (data) => profile == null
            ? _EmptyWizard()
            : _ScheduleView(
                data: data,
                profile: profile,
                semesterOverride: _semesterOverride,
                weekOffset: _weekOffset,
                showTheory: _showTheory,
                showLabs: _showLabs,
                onSemester: (s) => setState(() => _semesterOverride = s),
                onWeek: (d) => setState(() => _weekOffset += d),
                onResetWeek: () => setState(() => _weekOffset = 0),
                onTheory: (v) => setState(() => _showTheory = v),
                onLabs: (v) => setState(() => _showLabs = v),
              ),
      ),
    );
  }
}

class _EmptyWizard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Todavía no has configurado tu curso', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Elige tu año, tus asignaturas y tus turnos de laboratorio para '
              'ver tu semana real.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WizardScreen()),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('Configurar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({
    required this.data,
    required this.profile,
    required this.semesterOverride,
    required this.weekOffset,
    required this.showTheory,
    required this.showLabs,
    required this.onSemester,
    required this.onWeek,
    required this.onResetWeek,
    required this.onTheory,
    required this.onLabs,
  });

  final AcademicData data;
  final UserProfile profile;
  final int? semesterOverride;
  final int weekOffset;
  final bool showTheory;
  final bool showLabs;
  final ValueChanged<int> onSemester;
  final ValueChanged<int> onWeek;
  final VoidCallback onResetWeek;
  final ValueChanged<bool> onTheory;
  final ValueChanged<bool> onLabs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final active = semesterOverride ?? data.semesterAt(DateTime.now()) ?? 1;
    final semester = data.semesters.firstWhere((s) => s.id == active);
    final today = DateTime.now();

    final weekMonday = mondayOf(today).add(Duration(days: 7 * weekOffset));
    final isCurrentWeek = weekOffset == 0;

    var slots = projectSlots(data, profile, active);
    if (!showTheory) {
      slots = [for (final s in slots) if (s.kind != SlotKind.theory) s];
    }
    if (!showLabs) {
      slots = [for (final s in slots) if (s.kind != SlotKind.lab) s];
    }

    // Eventos del calendario académico que caen en cada día visible (L–V),
    // para marcarlos en el grid igual que en la pestaña Calendario.
    final dayEvents = <List<CalendarEvent>>[
      for (var d = 1; d <= 5; d++)
        data.eventsOn(weekMonday.add(Duration(days: d - 1))),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_shortDay(weekMonday)} – ${_shortDay(weekMonday.add(const Duration(days: 6)))}',
                  style: textTheme.titleMedium,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1Q')),
                  ButtonSegment(value: 2, label: Text('2Q')),
                ],
                selected: {active},
                onSelectionChanged: (s) => onSemester(s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        // Navegación de semana (una fila propia: nunca desborda).
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: () => onWeek(-1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Semana ${weekLabel(weekMonday, semester)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                onPressed: () => onWeek(1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        // Filtros (Teoría/Labs) + volver a la semana actual. Fila propia para
        // que la aparición de "Esta semana" no empuje ni desborde los filtros.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Teoría'),
                selected: showTheory,
                onSelected: onTheory,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Labs'),
                selected: showLabs,
                onSelected: onLabs,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (!isCurrentWeek)
                ActionChip(
                  avatar: const Icon(Icons.today, size: 16),
                  label: const Text('Esta semana'),
                  onPressed: onResetWeek,
                ),
            ],
          ),
        ),
        Expanded(
          child: slots.isEmpty
              ? _NoClasses()
              : _WeekGrid(
                  slots: slots,
                  monday: weekMonday,
                  today: isCurrentWeek ? today : null,
                  dayEvents: dayEvents,
                ),
        ),
      ],
    );
  }

  /// Número de semana dentro del semestre (empieza en 1).
  static String weekLabel(DateTime monday, SemesterInfo semester) {
    final startMonday = mondayOf(semester.classesStart);
    final n = (monday.difference(startMonday).inDays / 7).floor() + 1;
    return n < 1 ? 'en preparación' : '$n';
  }

  static String _shortDay(DateTime d) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _NoClasses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_florist_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          Text('No hay clases esta semana.', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Descansa o planifica: los huecos también cuentan.',
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- grid

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.slots,
    required this.monday,
    required this.today,
    required this.dayEvents,
  });

  final List<WeeklySlot> slots;

  /// Lunes de la semana mostrada.
  final DateTime monday;

  /// Si la semana mostrada es la actual, hoy (para la línea "ahora").
  final DateTime? today;

  /// Eventos del calendario académico por día visible (índice 0 = lunes).
  final List<List<CalendarEvent>> dayEvents;

  static const _dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  /// Distribuye solapamientos: cada tramo que se solapa recibe 1/n de ancho.
  static List<({WeeklySlot slot, int index, int count})> _layout(List<WeeklySlot> daySlots) {
    final sorted = [...daySlots]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final result = <({WeeklySlot slot, int index, int count})>[];
    var i = 0;
    while (i < sorted.length) {
      var clusterEnd = sorted[i].endMinutes;
      var j = i + 1;
      while (j < sorted.length && sorted[j].startMinutes < clusterEnd) {
        if (sorted[j].endMinutes > clusterEnd) clusterEnd = sorted[j].endMinutes;
        j++;
      }
      final n = j - i;
      for (var k = i; k < j; k++) {
        result.add((slot: sorted[k], index: k - i, count: n));
      }
      i = j;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // El grid se adapta al espacio disponible para que la semana completa
    // (L–V, 08:00–20:30) quepa en pantalla sin scroll siempre que se
    // respeten los mínimos de legibilidad.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availW = constraints.maxWidth;
        final double availH = constraints.maxHeight;
        final double totalHours = (_lastMinute - _firstMinute) / 60.0; // 12,5 h

        // Cabecera del día: algo más baja en pantallas muy bajas. Si algún
        // día de la semana tiene eventos (festivo, no lectivo…), se reserva
        // sitio bajo el nombre del día para sus marcadores.
        final double baseHeaderH = availH < 320 ? 34 : _dayHeaderHeight;
        var maxMarkers = 0;
        for (final evs in dayEvents) {
          if (evs.length > maxMarkers) maxMarkers = evs.length;
        }
        // Se dibujan como mucho 2 marcadores + un contador "+n".
        if (maxMarkers > 2) maxMarkers = 3;
        final bool weekHasMarkers = maxMarkers > 0;
        final double headerH =
            baseHeaderH + (weekHasMarkers ? 8 + maxMarkers * 15 : 0);

        // Ajuste vertical: se reparte lo que quede tras la cabecera; si no
        // llega al mínimo legible por hora, el grid crece (y vuelve el scroll).
        final double gridHeight =
            (availH - headerH) / totalHours >= _minHourHeight
                ? availH - headerH
                : totalHours * _minHourHeight;
        final double hourHeight = gridHeight / totalHours;

        // Ajuste horizontal: gutter + 5 columnas iguales que llenan el ancho
        // (respetando el mínimo legible por columna).
        final double totalW = (availW - _gutterWidth) / 5 >= _minColWidth
            ? availW
            : _gutterWidth + 5 * _minColWidth;
        final double colWidth = (totalW - _gutterWidth) / 5;

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _gutterWidth,
                  child: Column(
                    children: [
                      SizedBox(height: headerH),
                      SizedBox(
                        height: gridHeight,
                        // La etiqueta de 08:00 sobresale 7 px por encima del
                        // grid para centrarse en la línea de hora: sin clip
                        // para que no se corte por la mitad.
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var h = 8; h <= 20; h += 2)
                              Positioned(
                                top: (h * 60 - _firstMinute) / 60.0 * hourHeight - 7,
                                left: 6,
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: hourHeight < 38 ? 10 : 11,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (var day = 1; day <= 5; day++)
                  _DayColumn(
                    name: _dayNames[day - 1],
                    emphasized: today != null && today!.weekday == day,
                    slots: _layout([for (final s in slots) if (s.day == day) s]),
                    events: dayEvents[day - 1],
                    gridHeight: gridHeight,
                    hourHeight: hourHeight,
                    headerHeight: headerH,
                    width: colWidth,
                    nowMinutes: today != null && today!.weekday == day
                        ? today!.hour * 60 + today!.minute
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.name,
    required this.emphasized,
    required this.slots,
    required this.events,
    required this.gridHeight,
    required this.hourHeight,
    required this.headerHeight,
    required this.width,
    required this.nowMinutes,
  });

  final String name;
  final bool emphasized;
  final List<({WeeklySlot slot, int index, int count})> slots;

  /// Eventos del calendario académico que caen en este día de la semana.
  final List<CalendarEvent> events;

  /// Alto total de la zona horaria del día (sin la cabecera con el nombre).
  final double gridHeight;

  /// Alto de una hora en píxeles (el grid se adapta a la pantalla).
  final double hourHeight;

  /// Alto de la cabecera con el nombre del día.
  final double headerHeight;

  /// Ancho de la columna del día (se adapta a la pantalla).
  final double width;

  /// Minutos de hoy (para la línea "ahora"); null si no es el día de hoy.
  final int? nowMinutes;

  static const Map<String, String> _shortNames = {
    'Lunes': 'Lun',
    'Martes': 'Mar',
    'Miércoles': 'Mié',
    'Jueves': 'Jue',
    'Viernes': 'Vie',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    double topOf(WeeklySlot s) => (s.startMinutes - _firstMinute) / 60.0 * hourHeight;
    double heightOf(WeeklySlot s) => s.durationMinutes / 60.0 * hourHeight;

    // El nombre del día se abrevia según el ancho disponible de la columna.
    final String dayLabel = width >= 78
        ? name
        : width >= 56
            ? (_shortNames[name] ?? name)
            : name.substring(0, 1);

    // Pastilla con el nombre del día.
    Widget dayPill() => Container(
          padding: EdgeInsets.symmetric(
            horizontal: width < 64 ? 4 : 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: emphasized ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            dayLabel,
            maxLines: 1,
            style: textTheme.labelLarge?.copyWith(
              color: emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: width < 78 ? 11 : 14,
            ),
          ),
        );

    // Marcador de evento (pastilla estrecha, igual que en Calendario).
    Widget markerRow(CalendarEvent e) => Container(
          height: 13,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _markerColorOf(e.type),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            _eventChipLabel(e),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: _markerTextColorOf(e.type),
              height: 1,
            ),
          ),
        );

    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: events.isEmpty
                ? Center(child: dayPill())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      dayPill(),
                      const SizedBox(height: 3),
                      for (var i = 0; i < events.length && i < 2; i++)
                        markerRow(events[i]),
                      if (events.length > 2)
                        Container(
                          height: 11,
                          width: double.infinity,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '+${events.length - 2}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                              height: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SizedBox(
            height: gridHeight,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Línea vertical de la columna (superpuesta al grid, sin
                // ocupar altura propia).
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(color: scheme.outlineVariant),
                ),
                // Lavado suave cuando el día es festivo / no lectivo /
                // vacaciones (se ve que no hay clase, pero las tarjetas se
                // siguen mostrando encima).
                if (events.any(_isNoClassDay))
                  Container(
                    margin: const EdgeInsets.fromLTRB(3, 2, 3, 4),
                    decoration: BoxDecoration(
                      color: _markerColorOf(events.firstWhere(_isNoClassDay).type)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                if (emphasized)
                  Container(
                    margin: const EdgeInsets.fromLTRB(3, 0, 3, 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                // Líneas de hora sutiles: ayudan a leer el grid compacto.
                for (var h = 8; h <= 20; h++)
                  Positioned(
                    top: (h * 60 - _firstMinute) / 60.0 * hourHeight,
                    left: 0,
                    right: 0,
                    child: ColoredBox(
                      color: scheme.outlineVariant.withValues(alpha: 0.45),
                      child: const SizedBox(height: 1),
                    ),
                  ),
                for (final entry in slots)
                  Positioned(
                    top: topOf(entry.slot),
                    height: heightOf(entry.slot),
                    left: 2 + (entry.count > 1 ? entry.index * _overlapStep : 0),
                    width: (width - 4) -
                        (entry.count > 1 ? (entry.count - 1) * _overlapStep : 0),
                    child: entry.count > 1
                        ? Opacity(
                            opacity: 0.82,
                            child: _SlotCard(
                              slot: entry.slot,
                              courseName: _courseName(context, entry.slot.courseCode),
                              overlapping: true,
                            ),
                          )
                        : _SlotCard(
                            slot: entry.slot,
                            courseName: _courseName(context, entry.slot.courseCode),
                          ),
                  ),
                if (nowMinutes != null)
                  Positioned(
                    top: (nowMinutes!.clamp(_firstMinute, _lastMinute) - _firstMinute) /
                        60.0 *
                        hourHeight,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(height: 2, color: scheme.primary),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _courseName(BuildContext context, String code) {
    final data = ProviderScope.containerOf(context, listen: false)
            .read(academicDataProvider)
            .valueOrNull;
    return data == null ? code : data.courseByCode(code).displayName;
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.courseName,
    this.overlapping = false,
  });

  final WeeklySlot slot;
  final String courseName;

  /// Dibuja la tarjeta de forma translúcida cuando hay clases solapadas.
  final bool overlapping;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Color container = CoursePalette.containerOf(slot.courseCode);
    final Color onColor = CoursePalette.onContainerOf(slot.courseCode);
    final bool isLab = slot.kind == SlotKind.lab;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
      decoration: BoxDecoration(
        color: container.withValues(alpha: overlapping ? 0.82 : 1.0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: onColor.withValues(alpha: overlapping ? 0.6 : 0.35),
          width: overlapping ? 1.6 : 1.2,
        ),
      ),
      // Padding vertical pequeño: ahora el grid se adapta a la pantalla y
      // las celdas de 1 h son más bajas que antes.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double h = constraints.maxHeight;
          final String time = slot.startEndLabel;
          final String? group = isLab ? slot.group : null;
          // Solo los grupos simples (L1–L4) caben como pastilla en celdas
          // bajas; los combinados ("L2 y L3") se indican en la línea de hora.
          final bool pillable = group != null && RegExp(r'^L[1-4]$').hasMatch(group);

          // Pastilla minúscula con el grupo, para distinguir laboratorios
          // aunque la celda sea baja.
          Widget groupPill(double fontSize) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: onColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                group!,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.2,
                  color: container,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          // ── Micro (celdas muy bajas): 1 línea, [grupo] + nombre ─────────
          if (h < 24) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (pillable) ...[
                  groupPill(7.5),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            );
          }

          final bool full = h >= 62;

          // ── Compacta (≈1 h): [grupo] + nombre, hora (y aula) debajo ─────
          if (!full) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (pillable) ...[
                      groupPill(h < 36 ? 8 : 9),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.w700,
                          fontSize: h < 36 ? 10 : 11,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '$time${group != null && !pillable ? ' · $group' : ''}'
                  '${slot.classroom != null ? ' · ${slot.classroom}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: onColor.withValues(alpha: 0.8),
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
              ],
            );
          }

          // ── Completa (≥2 h): pastilla Ln + nombre + hora + aula ─────────
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLab) ...[
                _Badge(group: slot.group ?? 'Lab', container: container, onColor: onColor),
                const SizedBox(height: 2),
              ],
              Flexible(
                child: Text(
                  courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: onColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
              if (slot.classroom != null)
                Text(
                  slot.classroom!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: onColor.withValues(alpha: 0.8),
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.group, required this.container, required this.onColor});

  final String group;
  final Color container;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: onColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        group,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: container,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
      ),
    );
  }
}
