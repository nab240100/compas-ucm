import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/course_palette.dart';
import '../../data/exam_planning.dart' show countdownLabel;
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/projection.dart';
import '../../state/providers.dart';

/// Pantalla "Hoy": próxima clase con cuenta atrás, agenda del día y
/// estado del curso.
class HoyScreen extends ConsumerWidget {
  const HoyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(academicDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(error: error),
          data: (data) => _HoyView(data: data, profile: profile),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No se pudieron cargar los datos académicos.\n$error',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _HoyView extends StatelessWidget {
  const _HoyView({required this.data, required this.profile});

  final AcademicData data;
  final UserProfile? profile;

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _esDate(DateTime d, {bool withYear = false}) {
    const weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final base = '${weekdays[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]}';
    return withYear ? '$base de ${d.year}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DateTime today = DateTime.now();
    final int? semester = data.semesterAt(today);
    final List<CalendarEvent> todayEvents = data.eventsOn(today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          _capitalize(_esDate(today)),
          style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola', style: textTheme.headlineLarge),
                  const SizedBox(height: 2),
                  Text(
                    '${data.meta.academicYear}${profile == null ? '' : ' · ${profile!.yearsLabel} curso'}',
                    style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: Icon(Icons.school_outlined, size: 18, color: scheme.onSecondaryContainer),
              backgroundColor: scheme.secondaryContainer,
              label: Text('Curso activo'),
              labelStyle:
                  textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (profile != null)
          _NextClassCard(data: data, profile: profile!, now: today)
        else
          const _NeedsConfigCard(),
        const SizedBox(height: 16),
        if (profile != null)
          _TodayCard(
            data: data,
            profile: profile!,
            today: today,
            events: todayEvents,
            semester: semester,
          ),
        const SizedBox(height: 16),
        _SemesterCard(data: data, activeSemester: semester),
      ],
    );
  }
}

/// Tarjeta hero: próxima clase o estado "sin clases".
class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.data, required this.profile, required this.now});

  final AcademicData data;
  final UserProfile profile;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final next = nextClass(data, profile, now);

    if (next == null) {
      // Sin clases: periodo de exámenes, entre periodos o curso terminado.
      final period = nextClassPeriod(data, now);
      final extraordinary = data.extraordinaryExamPeriod.includes(now);
      final String title;
      final String subtitle;
      if (extraordinary) {
        title = 'Convocatoria extraordinaria';
        subtitle = '¡Ánimo! Los resultados salen pronto.';
      } else if (period != null) {
        title = 'Sin clases por ahora';
        subtitle = 'Las clases vuelven el ${period.classesStart.day} de '
            '${_month(period.classesStart.month)}';
      } else {
        title = 'Curso terminado';
        subtitle = 'Disfruta del verano; el próximo curso llegará a la app.';
      }
      return Card(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.park_outlined, size: 40, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final course = data.courseByCode(next.slot.courseCode);
    final container = CoursePalette.containerOf(course.code);
    final onContainer = CoursePalette.onContainerOf(course.code);
    final isToday = AcademicData.sameDay(next.day, now);
    final days = daysBetween(next.day, now);
    final minutes = isToday
        ? next.slot.startMinutes - (now.hour * 60 + now.minute)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Siguiente clase',
                  style: textTheme.labelLarge?.copyWith(
                    color: onContainer.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course.name,
                  style: textTheme.titleLarge?.copyWith(
                    color: onContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isToday ? 'Hoy' : _dayLabel(next.day)} · ${next.slot.startEndLabel}'
                  '${next.slot.classroom != null ? ' · ${next.slot.classroom}' : ''}'
                  '${next.slot.group != null ? ' · ${next.slot.group}' : ''}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: onContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: onContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              minutes != null ? untilLabel(minutes) : countdownLabel(days),
              style: textTheme.labelLarge?.copyWith(
                color: container,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int daysBetween(DateTime day, DateTime now) {
    final a = DateTime(day.year, day.month, day.day);
    final b = DateTime(now.year, now.month, now.day);
    return a.difference(b).inDays;
  }

  static String _dayLabel(DateTime d) {
    if (AcademicData.sameDay(d, DateTime.now().add(const Duration(days: 1)))) {
      return 'Mañana';
    }
    const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return '${weekdays[d.weekday - 1]} ${d.day} ${_month(d.month)}';
  }

  static String _month(int m) => const [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
      ][m - 1];
}

class _NeedsConfigCard extends StatelessWidget {
  const _NeedsConfigCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.self_improvement, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura tu curso',
                    style: textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Elige tus asignaturas y tendrás aquí tu próxima clase.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta del día: estado del curso + línea del tiempo de las clases.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.data,
    required this.profile,
    required this.today,
    required this.events,
    required this.semester,
  });

  final AcademicData data;
  final UserProfile profile;
  final DateTime today;
  final List<CalendarEvent> events;
  final int? semester;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    final holiday = events.isNotEmpty;
    final classDay = inClassPeriod(data, today) && semester != null && !holiday;
    final slots = classDay
        ? classesOnWeekday(data, profile, today, semester!)
        : <WeeklySlot>[];

    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (holiday) {
      final e = events.first;
      (icon, title, subtitle) = switch (e.type) {
        EventType.festivo =>
          (Icons.celebration_outlined, e.name, 'Día festivo'),
        EventType.noLectivo => (Icons.coffee_outlined, e.name, 'Día no lectivo'),
        EventType.vacaciones => (Icons.beach_access_outlined, e.name, 'Vacaciones'),
        EventType.welcome =>
          (Icons.waving_hand_outlined, e.name, 'Acto de bienvenida'),
        EventType.recovery => (Icons.refresh, e.name, 'Día de recuperación'),
        EventType.otro => (Icons.event_outlined, e.name, 'Evento del curso'),
      };
    } else if (semester != null && !classDay) {
      icon = Icons.edit_calendar_outlined;
      title = 'Periodo de exámenes';
      subtitle = 'Sin clases: a repasar';
    } else if (classDay) {
      icon = Icons.eco_outlined;
      title = slots.isEmpty ? 'Día libre' : 'Hoy en clase';
      subtitle = slots.isEmpty
          ? 'Sin clases para tus asignaturas hoy'
          : '${slots.length} clase${slots.length == 1 ? '' : 's'} programada${slots.length == 1 ? '' : 's'}';
    } else {
      icon = Icons.park_outlined;
      title = 'Entre periodos';
      subtitle = 'Relájate: todavía no hay clases';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (classDay && slots.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 6),
              for (final s in slots)
                _TimelineRow(
                  slot: s,
                  courseName: data.courseByCode(s.courseCode).name,
                  isNext: s.endMinutes > nowMinutes,
                  isPast: s.endMinutes <= nowMinutes,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de la línea del tiempo de hoy.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.slot,
    required this.courseName,
    required this.isNext,
    required this.isPast,
  });

  final WeeklySlot slot;
  final String courseName;
  final bool isNext;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isNext
                  ? scheme.primary
                  : (isPast ? scheme.surfaceContainerHighest : CoursePalette.containerOf(slot.courseCode)),
              shape: BoxShape.circle,
              border: isPast
                  ? Border.all(color: scheme.outlineVariant)
                  : Border.all(color: CoursePalette.onContainerOf(slot.courseCode), width: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              slot.startEndLabel,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: isPast ? scheme.onSurfaceVariant : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                color: isPast ? scheme.onSurfaceVariant : null,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (slot.group != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                slot.group!,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (slot.classroom != null) ...[
            const SizedBox(width: 8),
            Text(
              slot.classroom!,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({required this.data, required this.activeSemester});

  final AcademicData data;
  final int? activeSemester;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El año en dos semestres', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final s in data.semesters)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: activeSemester == s.id
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.id}º semestre', style: textTheme.titleSmall),
                          Text(
                            'Clases: ${s.classesLabel} · Exámenes: ${s.examsLabel}',
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
            Text(
              'Extraordinaria: ${_rangeLabel(data.extraordinaryExamPeriod)}',
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static String _rangeLabel(DateRange r) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}-${x.month.toString().padLeft(2, '0')}';
    return '${d(r.start)} – ${d(r.end)}';
  }
}
