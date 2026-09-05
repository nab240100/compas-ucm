import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/course_palette.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/projection.dart';
import '../../state/providers.dart';

/// Asistente de configuración: cursos (desplegables con asignaturas) →
/// turnos de laboratorio.
///
/// En primer arranque se muestra en lugar de la carcasa; en modo edición se
/// abre como ruta desde Ajustes.
class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  int _step = 0;

  /// Cursos con su tarjeta desplegada en el paso 1.
  final Set<int> _expanded = {};

  UserProfile? _draft;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(academicDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? 'Edita tu curso' : 'Configura tu curso'),
        automaticallyImplyLeading: widget.editMode,
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los datos.\n$e')),
        data: (data) {
          final draft = _draft ??= _initialDraft(data);
          return Column(
            children: [
              _ProgressBar(step: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  child: switch (_step) {
                    0 => _StepYears(
                        key: const ValueKey(0),
                        data: data,
                        draft: draft,
                        expanded: _expanded,
                        onToggleExpand: (year) => setState(() {
                          _expanded.contains(year) ? _expanded.remove(year) : _expanded.add(year);
                        }),
                        onToggleCourse: (code, selected) =>
                            setState(() => _toggleCourse(data, draft, code, selected)),
                        onToggleAll: (year) => setState(() => _toggleAll(data, draft, year)),
                      ),
                    _ => _StepLabs(
                        key: const ValueKey(1),
                        data: data,
                        draft: draft,
                        onTurn: (code, group) => setState(() {
                          final turns = Map<String, String>.from(draft.labTurns);
                          turns[code] = group;
                          _draft = draft.copyWith(labTurns: turns);
                        }),
                      ),
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton.icon(
                          onPressed: () => setState(() => _step -= 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Atrás'),
                        )
                      else
                        const SizedBox(width: 8),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _step == 1 ? () => _finish(data, draft) : () => _next(draft),
                        icon: Icon(_step == 1 ? Icons.rocket_launch_outlined : Icons.arrow_forward),
                        label: Text(_step == 1 ? '¡Empezar!' : 'Siguiente'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  UserProfile _initialDraft(AcademicData data) {
    final existing = ref.read(profileProvider).valueOrNull;
    if (existing != null && widget.editMode) return existing;
    if (existing != null && !widget.editMode) return existing; // wizard ya configurado
    return UserProfile.defaults();
  }

  /// Cambia una asignatura y mantiene sincronizados los cursos derivados.
  void _toggleCourse(AcademicData data, UserProfile draft, String code, bool selected) {
    final codes = Set<String>.from(draft.selectedCourseCodes);
    selected ? codes.add(code) : codes.remove(code);
    _draft = draft.copyWith(
      selectedCourseCodes: codes,
      years: _yearsOf(data, codes),
    );
  }

  /// Marca/desmarca todas las asignaturas de un curso desplegado.
  void _toggleAll(AcademicData data, UserProfile draft, int year) {
    final yearCourses = [
      for (final c in coursesOfYear(data, year)) c.code,
    ];
    final allSelected = yearCourses
        .toSet()
        .every(draft.selectedCourseCodes.contains);
    final codes = Set<String>.from(draft.selectedCourseCodes);
    if (allSelected) {
      // Al desmarcar: solo las que pertenecen en exclusiva al curso (las
      // optativas compartidas no se tocan si el otro curso sigue activo).
      codes.removeWhere((code) {
        final c = data.courseByCode(code);
        return c.years.length == 1 && c.years.first == year;
      });
    } else {
      codes.addAll(yearCourses);
    }
    _draft = draft.copyWith(
      selectedCourseCodes: codes,
      years: _yearsOf(data, codes),
    );
  }

  /// Cursos derivados de la selección (para el perfil y la etiqueta).
  List<int> _yearsOf(AcademicData data, Set<String> codes) {
    final years = <int>{};
    for (final c in data.courses) {
      if (codes.contains(c.code)) years.addAll(c.years);
    }
    return years.toList()..sort();
  }

  void _next(UserProfile draft) {
    final data = ref.read(academicDataProvider).valueOrNull;
    if (data == null) return;
    if (draft.selectedCourseCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos una asignatura.')),
      );
      return;
    }
    setState(() {
      _draft = fillMissingLabTurns(data, draft);
      _step += 1;
    });
  }

  Future<void> _finish(AcademicData data, UserProfile draft) async {
    final profile = fillMissingLabTurns(data, draft);
    await ref.read(profileProvider.notifier).save(profile);
    if (widget.editMode && mounted) Navigator.of(context).pop();
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  static const _labels = ['Cursos', 'Laboratorios'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= step ? scheme.primary : scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: i <= step ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < _labels.length - 1)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i < step ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- paso 1

class _StepYears extends StatelessWidget {
  const _StepYears({
    super.key,
    required this.data,
    required this.draft,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggleCourse,
    required this.onToggleAll,
  });

  final AcademicData data;
  final UserProfile draft;
  final Set<int> expanded;
  final ValueChanged<int> onToggleExpand;
  final void Function(String code, bool selected) onToggleCourse;
  final ValueChanged<int> onToggleAll;

  static const _yearNames = ['Primer', 'Segundo', 'Tercer', 'Cuarto'];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = draft.selectedCourseCodes.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Text('¿En qué cursos estás?', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Toca un curso para desplegar sus asignaturas y marca las que '
          'curses. Puedes combinar varios, por ejemplo 3º y 4º.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (var year = 1; year <= 4; year++)
          _YearCard(
            year: year,
            yearName: _yearNames[year - 1],
            data: data,
            draft: draft,
            expanded: expanded.contains(year),
            onToggleExpand: () => onToggleExpand(year),
            onToggleCourse: onToggleCourse,
            onToggleAll: () => onToggleAll(year),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              total == 0
                  ? 'Aún no has marcado asignaturas'
                  : '$total asignaturas en tu selección'
                      '${draft.years.isEmpty ? '' : ' (${draft.yearsLabel})'}',
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta de curso: cabecera plegable + asignaturas desplegadas.
class _YearCard extends StatelessWidget {
  const _YearCard({
    required this.year,
    required this.yearName,
    required this.data,
    required this.draft,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggleCourse,
    required this.onToggleAll,
  });

  final int year;
  final String yearName;
  final AcademicData data;
  final UserProfile draft;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final void Function(String code, bool selected) onToggleCourse;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final courses = coursesOfYear(data, year);
    final selectedHere = [
      for (final c in courses)
        if (draft.selectedCourseCodes.contains(c.code)) c,
    ];
    final electives = courses.where((c) => c.elective).length;
    final bool allSelected = selectedHere.length == courses.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: expanded ? scheme.surfaceContainerLow : null,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    '$yearº',
                    style: textTheme.headlineMedium?.copyWith(
                      color: selectedHere.isNotEmpty ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$yearName curso', style: textTheme.titleMedium),
                        Text(
                          '${courses.length} asignaturas'
                          '${electives > 0 ? ' · $electives optativas' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedHere.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedHere.length}',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Asignaturas de $yearº',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: onToggleAll,
                              icon: Icon(
                                allSelected ? Icons.deselect : Icons.done_all,
                                size: 18,
                              ),
                              label: Text(allSelected ? 'Ninguna' : 'Todas'),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in courses)
                              FilterChip(
                                selected: draft.selectedCourseCodes.contains(c.code),
                                onSelected: (sel) =>
                                    onToggleCourse(c.code, sel),
                                selectedColor: scheme.primaryContainer,
                                checkmarkColor: scheme.onPrimaryContainer,
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (c.elective) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          'OPT',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: scheme.tertiary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      if (c.special != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          c.special == 'tfg' ? 'TFG' : 'PRACT',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- paso 2

class _StepLabs extends StatelessWidget {
  const _StepLabs({super.key, required this.data, required this.draft, required this.onTurn});

  final AcademicData data;
  final UserProfile draft;
  final void Function(String code, String group) onTurn;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final selected = [
      for (final c in data.courses)
        if (draft.selectedCourseCodes.contains(c.code)) c,
    ]..sort((a, b) {
        final byYear = a.years.first.compareTo(b.years.first);
        return byYear != 0 ? byYear : a.name.compareTo(b.name);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Text('Tus grupos de laboratorio', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Elige tu turno para cada asignatura con prácticas. Se respeta tu '
          'grupo en el horario.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final c in selected)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: CoursePalette.containerOf(c.code),
                          shape: BoxShape.circle,
                          border: Border.all(color: CoursePalette.onContainerOf(c.code), width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(c.name, style: textTheme.titleSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  labGroupsOf(data, c.code).isEmpty
                      ? Text(
                          'Sin laboratorio semanal',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Wrap(
                          spacing: 8,
                          children: [
                            for (final g in labGroupsOf(data, c.code))
                              ChoiceChip(
                                label: Text(g),
                                selected: draft.labTurns[c.code] == g,
                                onSelected: (_) => onTurn(c.code, g),
                                selectedColor: scheme.primaryContainer,
                                checkmarkColor: scheme.onPrimaryContainer,
                              ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        if (labCount() == 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.eco_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ninguna de tus asignaturas tiene laboratorio este año.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  int labCount() {
    var n = 0;
    for (final code in draft.selectedCourseCodes) {
      if (labGroupsOf(data, code).isNotEmpty) n++;
    }
    return n;
  }
}
