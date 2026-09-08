import 'package:flutter/material.dart';

import '../../core/theme/course_palette.dart';
import '../../data/models.dart';

/// Abre el detalle de una clase del horario en un bottom sheet modal.
///
/// Muestra lo que ya sabemos de la asignatura (profesor/a coordinador,
/// despacho, aula, horario, grupo…). En pasos siguientes se añadirán
/// acciones: recordatorio, añadir al calendario (ICS), exámenes asociados…
Future<void> showClassDetails(
  BuildContext context,
  AcademicData data,
  WeeklySlot slot,
) {
  final course = data.courseByCode(slot.courseCode);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ClassDetailsSheet(course: course, slot: slot),
  );
}

/// Hoja de detalle de una clase concreta (un `WeeklySlot` + su `Course`).
class ClassDetailsSheet extends StatelessWidget {
  const ClassDetailsSheet({super.key, required this.course, required this.slot});

  final Course course;
  final WeeklySlot slot;

  static const List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final Color container = CoursePalette.containerOf(course.code);
    final Color onColor = CoursePalette.onContainerOf(course.code);
    final bool isLab = slot.kind == SlotKind.lab;

    final String aula = slot.classroom ?? course.classroom ?? '';
    final String dia = _dayNames[slot.day - 1];
    final bool enOtroSemestre = course.semesters.length > 1 &&
        course.semesters.contains(3 - slot.semester);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabecera: asignatura + tipo/grupo ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: container,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: textTheme.titleLarge?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _KindChip(
                        label: isLab ? 'Laboratorio' : 'Teoría',
                        onColor: onColor,
                        container: container,
                      ),
                      if (isLab && slot.group != null) ...[
                        const SizedBox(width: 6),
                        _KindChip(
                          label: 'Grupo ${slot.group}',
                          onColor: onColor,
                          container: container,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        course.code,
                        style: textTheme.labelMedium?.copyWith(
                          color: onColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Horario ───────────────────────────────────────────────────
            _InfoRow(
              icon: Icons.schedule,
              label: 'Horario',
              value: '$dia · ${slot.startEndLabel}',
            ),
            if (aula.isNotEmpty)
              _InfoRow(icon: Icons.meeting_room_outlined, label: 'Aula', value: aula),
            if (course.profesor != null && course.profesor!.isNotEmpty)
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Profesor/a',
                value: course.profesor!,
              ),
            if (course.profesorOffice != null && course.profesorOffice!.isNotEmpty)
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Despacho',
                value: course.profesorOffice!,
              ),
            _InfoRow(
              icon: Icons.calendar_view_week_outlined,
              label: 'Semestre',
              value: '${slot.semester}º semestre'
                  '${enOtroSemestre ? ' (también en ${3 - slot.semester}º)' : ''}',
            ),
            const SizedBox(height: 8),
            Text(
              'Los datos proceden de la Guía Docente oficial de la facultad.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.onColor,
    required this.container,
  });

  final String label;
  final Color onColor;
  final Color container;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: container,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
