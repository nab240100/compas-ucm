import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/appearance.dart';
import 'features/shell/home_shell.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: CompasUcmApp()));
}

/// Compás UCM — horario y calendario del Grado en Ingeniería
/// Electrónica de Comunicaciones.
class CompasUcmApp extends ConsumerWidget {
  const CompasUcmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(appearanceProvider).valueOrNull ?? AppearancePrefs.defaults();
    final Color seed = switch (prefs.seed) {
      AppearanceSeed.terra => AppSeeds.terra,
      AppearanceSeed.salvia => AppSeeds.salvia,
      AppearanceSeed.miel => AppSeeds.miel,
      AppearanceSeed.rosa => AppSeeds.rosa,
      AppearanceSeed.lavanda => AppSeeds.lavanda,
      AppearanceSeed.celeste => AppSeeds.celeste,
      AppearanceSeed.menta => AppSeeds.menta,
      AppearanceSeed.oceano => AppSeeds.oceano,
      AppearanceSeed.system => AppSeeds.terra,
    };

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ThemeMode mode = switch (prefs.mode) {
          AppearanceMode.system => ThemeMode.system,
          AppearanceMode.light => ThemeMode.light,
          AppearanceMode.dark => ThemeMode.dark,
        };
        final bool useDynamic = prefs.seed == AppearanceSeed.system;

        return MaterialApp(
          title: 'Compás UCM',
          debugShowCheckedModeBanner: false,
          theme: useDynamic && lightDynamic != null
              ? AppTheme.fromScheme(lightDynamic)
              : AppTheme.light(seed: seed),
          darkTheme: useDynamic && darkDynamic != null
              ? AppTheme.fromScheme(darkDynamic)
              : AppTheme.dark(seed: seed),
          themeMode: mode,
          home: const HomeShell(),
        );
      },
    );
  }
}
