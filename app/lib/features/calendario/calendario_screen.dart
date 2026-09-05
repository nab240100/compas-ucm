import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/course_palette.dart';
import '../../data/calendar_planning.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/projection.dart';
import '../../state/providers.dart';

/// Colores de marcadores del calendario (armonizados con la paleta cálida).
class MarkerColors {
  MarkerColors._();

  static const festivo = Color(0xFFB98A2F); // miel
  static const noLectivo = Color(0xFF6F7D5C); // salvia
  static const vacaciones = Color(0xFF9A8B7A); // crema tostada
  static const welcome = Color(0xFFB85C38); // terra
  static const recovery = Color(0xFF6F5FA8); // lila oscuro
  static const examen = Color(0xFFB85C38); // terra

  static Color of(DayMarkerType t) => switch (t) {
        DayMarkerType.festivo => festivo,
        DayMarkerType.noLectivo => noLectivo,
        DayMarkerType.vacaciones => vacaciones,
        DayMarkerType.welcome => welcome,
        DayMarkerType.recovery => recovery,
        DayMarkerType.examen => examen,
      };

  /// Color de texto sobre la pastilla (contraste legible a 8-9px).
  static Color textOf(DayMarkerType t) => switch (t) {
        DayMarkerType.festivo => const Color(0xFF241703),
        DayMarkerType.vacaciones => const Color(0xFF231A10),
        _ => Colors.white,
      };
}

class MarkerLabel {
  const MarkerLabel(this.type, this.name, this.icon);

  final DayMarkerType type;
  final String name;
  final IconData icon;

  static const labels = [
    MarkerLabel(DayMarkerType.festivo, 'Festivo', Icons.celebration_outlined),
    MarkerLabel(DayMarkerType.noLectivo, 'No lectivo', Icons.coffee_outlined),
    MarkerLabel(DayMarkerType.vacaciones, 'Vacaciones', Icons.beach_access_outlined),
    MarkerLabel(DayMarkerType.examen, 'Examen', Icons.assignment_turned_in_outlined),
    MarkerLabel(DayMarkerType.recovery, 'Recuperación', Icons.refresh),
    MarkerLabel(DayMarkerType.welcome, 'Bienvenida', Icons.waving_hand_outlined),
  ];
}

/// Calendario anual del curso con festivos, no lectivos, exámenes y clases.
class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(academicDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            tooltip: 'Ir al mes actual',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => setState(
              () => _month = DateTime(DateTime.now().year, DateTime.now().month, 1),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los datos.\n$e')),
        data: (data) => Column(
          children: [
            _MonthHeader(month: _month, data: data, onShift: (d) => _shiftMonth(d, data)),
            const _WeekdayRow(),
            _Legend(),
            const SizedBox(height: 4),
            Expanded(
              child: _MonthGrid(
                month: _month,
                data: data,
                profile: profile,
                onDay: (day) => _showDay(context, data, profile, day),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navega de mes en mes dentro del rango del curso.
  void _shiftMonth(int delta, AcademicData data) {
    final min = minMonth(data);
    final max = maxMonth(data);
    final candidate = DateTime(_month.year, _month.month + delta, 1);
    if (candidate.isBefore(DateTime(min.year, min.month, 1)) ||
        candidate.isAfter(DateTime(max.year, max.month, 1))) {
      return;
    }
    setState(() => _month = candidate);
  }

  void _showDay(BuildContext context, AcademicData data, UserProfile? profile, DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DaySheet(data: data, profile: profile, day: day),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.data, required this.onShift});

  final DateTime month;
  final AcademicData data;
  final ValueChanged<int> onShift;

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final min = minMonth(data);
    final max = maxMonth(data);
    final canPrev =
        !DateTime(month.year, month.month, 1).isBefore(DateTime(min.year, min.month, 1));
    final canNext =
        !DateTime(month.year, month.month, 1).isAfter(DateTime(max.year, max.month, 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: canPrev ? () => onShift(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${_months[month.month - 1]} ${month.year}',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: canNext ? () => onShift(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          for (final d in esDays)
            Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (final l in MarkerLabel.labels)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: MarkerColors.of(l.type),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  l.name,
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.data,
    required this.profile,
    required this.onDay,
  });

  final DateTime month;
  final AcademicData data;
  final UserProfile? profile;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cells = monthCells(month.year, month.month);
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 76,
      ),
      itemCount: cells.length,
      itemBuilder: (context, i) {
        if (cells[i].date == null) return const SizedBox.shrink();
        final day = cells[i].date!;
        final markers = markersOn(data, profile, day);
        final isToday = AcademicData.sameDay(day, today);

        // Pastillas estilo Google Calendar (máx. 2 + overflow).
        final chips = <({DayMarkerType type, String label})>[
          for (final e in markers.exams)
            (
              type: DayMarkerType.examen,
              label: e.course.shortName ?? 'Examen',
            ),
          for (final e in markers.events) (type: _chipTypeOf(e), label: _chipLabelOf(e)),
        ];
        final visible = chips.take(2).toList();
        final overflow = chips.length - visible.length;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onDay(day),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (isToday)
                        Positioned(
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primaryContainer,
                              border: Border.all(color: scheme.primary, width: 1.5),
                            ),
                            child: Text(
                              '${day.day}',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          '${day.day}',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                if (visible.isNotEmpty)
                  for (final chip in visible) _DayChip(type: chip.type, label: chip.label),
                if (overflow > 0)
                  Container(
                    height: 15,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+$overflow',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        height: 1,
                      ),
                    ),
                  ),
                if (visible.isEmpty && markers.classDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.data, required this.profile, required this.day});

  final AcademicData data;
  final UserProfile? profile;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final markers = markersOn(data, profile, day);
    final semester = data.semesterAt(day);

    final weekSlots = profile == null || !inClassPeriod(data, day) || semester == null
        ? <WeeklySlot>[]
        : projectSlots(data, profile!, semester)
            .where((s) => s.day == day.weekday)
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(day),
              style: textTheme.headlineSmall,
            ),
            if (semester != null)
              Text(
                '$semesterº semestre',
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 16),

            // Eventos académicos
            if (markers.events.isEmpty && markers.exams.isEmpty && weekSlots.isEmpty)
              Text(
                'Sin eventos este día.',
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            for (final e in markers.events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _MarkerDot(color: MarkerColors.of(_typeOf(e))),
                title: Text(e.name, style: textTheme.titleSmall),
                subtitle: Text(
                  _eventTypeLabel(e.type),
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),

            // Exámenes del usuario
            for (final e in markers.exams)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _MarkerDot(color: MarkerColors.examen),
                title: Text(e.label, style: textTheme.titleSmall),
                subtitle: Text(
                  '${e.call} · ${e.timeKnown ? e.time : 'hora por publicar'}'
                  '${e.room != null ? ' · ${e.room}' : ''}',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),

            // Clases de ese día de la semana
            if (weekSlots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Clases', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final s in weekSlots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: CoursePalette.containerOf(s.courseCode),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.courseByCode(s.courseCode).name,
                              style: textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${s.startEndLabel}'
                              '${s.classroom != null ? ' · ${s.classroom}' : ''}'
                              '${s.group != null ? ' · ${s.group}' : ''}',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(DateTime d) {
    const weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final s = '${weekdays[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]} de ${d.year}';
    return s[0].toUpperCase() + s.substring(1);
  }

  static DayMarkerType _typeOf(CalendarEvent e) => switch (e.type) {
        EventType.festivo => DayMarkerType.festivo,
        EventType.noLectivo => DayMarkerType.noLectivo,
        EventType.vacaciones => DayMarkerType.vacaciones,
        EventType.welcome => DayMarkerType.welcome,
        EventType.recovery => DayMarkerType.recovery,
        EventType.otro => DayMarkerType.festivo,
      };

  static String _eventTypeLabel(EventType t) => switch (t) {
        EventType.festivo => 'Festivo',
        EventType.noLectivo => 'No lectivo',
        EventType.vacaciones => 'Vacaciones',
        EventType.welcome => 'Acto de bienvenida',
        EventType.recovery => 'Día de recuperación',
        EventType.otro => 'Evento',
      };
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Etiqueta compacta para la pastilla de un evento.
String _chipLabelOf(CalendarEvent e) => switch (e.name) {
      'Acto de bienvenida' => 'Bienvenida',
      'Día de recuperación' => 'Recup.',
      _ => e.name,
    };

DayMarkerType _chipTypeOf(CalendarEvent e) => switch (e.type) {
      EventType.festivo => DayMarkerType.festivo,
      EventType.noLectivo => DayMarkerType.noLectivo,
      EventType.vacaciones => DayMarkerType.vacaciones,
      EventType.welcome => DayMarkerType.welcome,
      EventType.recovery => DayMarkerType.recovery,
      EventType.otro => DayMarkerType.festivo,
    };

/// Pastilla de evento del día (estilo Google Calendar).
class _DayChip extends StatelessWidget {
  const _DayChip({required this.type, required this.label});

  final DayMarkerType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: MarkerColors.of(type),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: MarkerColors.textOf(type),
          height: 1,
        ),
      ),
    );
  }
}
