import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/course_palette.dart';
import '../../data/appearance.dart';
import '../../data/projection.dart';
import '../../state/providers.dart';
import '../setup/wizard_screen.dart';

/// Ajustes: resumen de la selección actual y acceso al asistente de edición.
class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(academicDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudieron cargar los datos.\n$e')),
        data: (data) {
          final appearance =
              ref.watch(appearanceProvider).valueOrNull ?? AppearancePrefs.defaults();
          if (profile == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const WizardScreen()),
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Configurar mi curso'),
              ),
            );
          }
          final selected = [
            for (final c in data.courses)
              if (profile.selectedCourseCodes.contains(c.code)) c,
          ]..sort((a, b) {
              final bySem = a.primarySemester.compareTo(b.primarySemester);
              return bySem != 0 ? bySem : a.name.compareTo(b.name);
            });
          final withLabs = [
            for (final c in selected)
              if (labGroupsOf(data, c.code).isNotEmpty) c,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            profile.yearsLabel,
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${profile.yearsLabel} curso · ${selected.length} asignaturas',
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              '${withLabs.length} con laboratorio · '
                              '${data.meta.academicYear}',
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
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const WizardScreen(editMode: true)),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar mi selección'),
              ),
              const SizedBox(height: 20),
              Text('Widget de horario', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.widgets_outlined,
                              size: 20, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Horario semanal', style: textTheme.titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Añádelo a tu pantalla de inicio: mantén pulsado el fondo '
                        '→ Widgets → Compás UCM → «Horario semanal» (4×4).',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'El widget se actualiza al abrir la app o al cambiar tu '
                        'selección de asignaturas.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Apariencia', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined,
                              size: 20, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text('Color del tema', style: textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final seed in AppearanceSeed.values)
                            ChoiceChip(
                              selected: appearance.seed == seed,
                              onSelected: (_) => ref
                                  .read(appearanceProvider.notifier)
                                  .setSeed(seed),
                              avatar: seed == AppearanceSeed.system
                                  ? Icon(Icons.wallpaper,
                                      size: 16,
                                      color: scheme.onSurfaceVariant)
                                  : _SeedDot(color: _seedColor(seed)),
                              label: Text(_seedLabel(seed)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Modo', style: textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<AppearanceMode>(
                        segments: const [
                          ButtonSegment(
                              value: AppearanceMode.light,
                              label: Text('Claro')),
                          ButtonSegment(
                              value: AppearanceMode.dark,
                              label: Text('Oscuro')),
                          ButtonSegment(
                              value: AppearanceMode.system,
                              label: Text('Sistema')),
                        ],
                        selected: {appearance.mode},
                        onSelectionChanged: (s) => ref
                            .read(appearanceProvider.notifier)
                            .setMode(s.first),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Mis asignaturas', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final c in selected)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: CoursePalette.containerOf(c.code),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CoursePalette.onContainerOf(c.code),
                              width: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: textTheme.titleSmall),
                              if (c.classroom != null)
                                Text(
                                  c.classroom!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (profile.labTurns[c.code] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              profile.labTurns[c.code]!,
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmReset(context, ref),
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  'Empezar de nuevo (borrar configuración)',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Empezar de nuevo?'),
        content: const Text(
          'Se borrará tu curso, asignaturas y turnos de laboratorio. '
          'Los datos académicos del curso no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(profileProvider.notifier).clear();
    }
  }
}

/// Punto de color para los chips de semilla.
class _SeedDot extends StatelessWidget {
  const _SeedDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
      ),
    );
  }
}

Color _seedColor(AppearanceSeed seed) => switch (seed) {
      AppearanceSeed.terra => AppSeeds.terra,
      AppearanceSeed.salvia => AppSeeds.salvia,
      AppearanceSeed.miel => AppSeeds.miel,
      AppearanceSeed.rosa => AppSeeds.rosa,
      AppearanceSeed.lavanda => AppSeeds.lavanda,
      AppearanceSeed.celeste => AppSeeds.celeste,
      AppearanceSeed.menta => AppSeeds.menta,
      AppearanceSeed.oceano => AppSeeds.oceano,
      AppearanceSeed.system => const Color(0xFF88A0B8),
    };

String _seedLabel(AppearanceSeed seed) => switch (seed) {
      AppearanceSeed.terra => 'Terra',
      AppearanceSeed.salvia => 'Salvia',
      AppearanceSeed.miel => 'Miel',
      AppearanceSeed.rosa => 'Rosa',
      AppearanceSeed.lavanda => 'Lavanda',
      AppearanceSeed.celeste => 'Celeste',
      AppearanceSeed.menta => 'Menta',
      AppearanceSeed.oceano => 'Océano',
      AppearanceSeed.system => 'Fondo de pantalla',
    };
