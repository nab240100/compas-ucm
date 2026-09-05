import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/course_palette.dart';
import '../../data/exam_planning.dart';
import '../../data/ics.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../state/providers.dart';
import '../setup/wizard_screen.dart';

/// Convocatorias de examen: ordinaria/extraordinaria, countdowns,
/// recordatorios, conflictos y exportación .ics.
class ExamenesScreen extends ConsumerStatefulWidget {
  const ExamenesScreen({super.key});

  @override
  ConsumerState<ExamenesScreen> createState() => _ExamenesScreenState();
}

class _ExamenesScreenState extends ConsumerState<ExamenesScreen> {
  String _call = 'ordinaria';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(academicDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exámenes'),
        actions: [
          IconButton(
            tooltip: 'Exportar a .ics',
            icon: const Icon(Icons.ios_share),
            onPressed: profile == null ? null : () => _share(dataAsync.valueOrNull, profile),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los datos.\n$e')),
        data: (data) {
          if (profile == null) return _EmptyConfigure();
          final all = examItems(data, profile);
          final items = [for (final e in all) if (e.call == _call) e];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ordinaria', label: Text('Ordinaria')),
                  ButtonSegment(value: 'extraordinaria', label: Text('Extraordinaria')),
                ],
                selected: {_call},
                onSelectionChanged: (s) => setState(() => _call = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                _EmptyExams(call: _call)
              else ...[
                _NextExamHero(items: items),
                for (final conflict in examConflicts(items)) _ConflictCard(conflict: conflict),
                const SizedBox(height: 8),
                for (final group in _groupByCall(items)) ...[
                  _SectionHeader(
                    title: group.$1,
                    count: group.$2.length,
                  ),
                  for (final e in group.$2) _ExamTile(item: e),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _share(data, profile),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Exportar esta convocatoria a .ics'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Agrupa por semestre manteniendo el orden por fecha.
  List<(String, List<ExamItem>)> _groupByCall(List<ExamItem> items) {
    final groups = <(String, List<ExamItem>)>[];
    for (final e in items) {
      final sem = e.course.primarySemester;
      final title = sem == 1 ? 'Primer semestre' : 'Segundo semestre';
      if (groups.isEmpty || groups.last.$1 != title) {
        groups.add((title, []));
      }
      groups.last.$2.add(e);
    }
    return groups;
  }

  Future<void> _share(AcademicData? data, UserProfile profile) async {
    if (data == null) return;
    final items = [
      for (final e in examItems(data, profile))
        if (e.call == _call) e,
    ];
    if (items.isEmpty) return;
    final ics = buildExamsIcs(items);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(ics.codeUnits),
            mimeType: 'text/calendar',
            name: 'examenes-$_call-2026-27.ics',
          ),
        ],
        subject: 'Exámenes Compás UCM (${_call == 'ordinaria' ? 'ordinaria' : 'extraordinaria'})',
      ),
    );
  }
}

class _EmptyConfigure extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Configura tu curso para ver tus exámenes',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
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

class _EmptyExams extends StatelessWidget {
  const _EmptyExams({required this.call});

  final String call;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.local_florist_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Sin exámenes en convocatoria ${call == 'ordinaria' ? 'ordinaria' : 'extraordinaria'}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Row(
        children: [
          Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta hero con el próximo examen y su cuenta atrás.
class _NextExamHero extends StatelessWidget {
  const _NextExamHero({required this.items});

  final List<ExamItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final upcoming = [
      for (final e in items)
        if (!e.date.isBefore(DateTime(now.year, now.month, now.day))) e,
    ];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;
    final days = daysUntil(next.date, now);
    final container = CoursePalette.containerOf(next.course.code);
    final onContainer = CoursePalette.onContainerOf(next.course.code);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  'Próximo examen',
                  style: textTheme.labelLarge?.copyWith(
                    color: onContainer.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next.label,
                  style: textTheme.titleLarge?.copyWith(
                    color: onContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${esShortDate(next.date)} · ${next.timeKnown ? next.time : 'hora por publicar'}',
                  style: textTheme.bodyMedium?.copyWith(color: onContainer.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: onContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              countdownLabel(days),
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
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});

  final List<ExamItem> conflict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${conflict.length} exámenes el mismo día',
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${conflict.first.label} y ${conflict.last.label} — '
                  '${esShortDate(conflict.first.date)}',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.item});

  final ExamItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final days = daysUntil(item.date, DateTime.now());
    final past = days < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(
                    '${item.date.day}',
                    style: textTheme.headlineSmall?.copyWith(
                      color: past ? scheme.onSurfaceVariant : scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _monthShort(item.date),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: scheme.outlineVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.timeKnown ? item.time : 'hora por publicar'}'
                    '${item.room != null ? ' · ${item.room}' : ''}'
                    ' · ${esShortDate(item.date)}',
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
    );
  }

  static String _monthShort(DateTime d) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return months[d.month - 1];
  }
}
