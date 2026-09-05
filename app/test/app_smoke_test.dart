import 'dart:math' show pow;

import 'package:compas_ucm/core/theme/app_theme.dart';
import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/appearance.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/main.dart';
import 'package:compas_ucm/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los datos académicos se cargan UNA vez fuera del entorno de fake-async
/// (rootBundle solo resuelve de forma fiable en `setUpAll`) y se inyectan vía
/// override. Sin I/O real dentro de los testWidgets.
late AcademicData loadedData;

/// Lanza la app con datos y repositorio de perfil inyectados.
Future<void> pumpApp(
  WidgetTester tester, {
  UserProfile? seeded,
  InMemoryProfileRepository? repo,
}) async {
  final repository = repo ?? InMemoryProfileRepository(seeded);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        academicDataProvider.overrideWith((ref) async => loadedData),
        profileRepositoryProvider.overrideWithValue(repository),
        appearanceRepositoryProvider.overrideWithValue(InMemoryAppearanceRepository()),
      ],
      child: const CompasUcmApp(),
    ),
  );
  await settleTaps(tester);
  await settleTaps(tester);
}

Future<void> settleTaps(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Recorre el asistente hasta el final (2º completo, asignaturas por defecto).
Future<void> completeWizard(WidgetTester tester) async {
  // Expande "Segundo curso" y marca todas sus asignaturas.
  await tester.tap(find.text('Segundo curso'));
  await settleTaps(tester);
  await tester.tap(find.text('Todas'));
  await settleTaps(tester);
  await tester.tap(find.text('Siguiente'));
  await settleTaps(tester);
  expect(find.text('Tus grupos de laboratorio'), findsOneWidget);
  await tester.tap(find.text('¡Empezar!'));
  await settleTaps(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    loadedData = await AcademicRepository.load();
  });

  testWidgets('el primer arranque muestra el asistente y lo completa', (tester) async {
    await pumpApp(tester);

    expect(find.text('Configura tu curso'), findsOneWidget);
    expect(find.text('¿En qué cursos estás?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await completeWizard(tester);

    // Ahora sí: carcasa con las 5 pestañas y la pantalla "Hoy".
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('2026-2027'), findsOneWidget);
    expect(find.text('Siguiente clase'), findsOneWidget);
  });

  testWidgets('el horario muestra las clases del curso elegido', (tester) async {
    await pumpApp(tester);
    await completeWizard(tester);

    await tester.tap(find.text('Horario'));
    await settleTaps(tester);

    // 2º curso, 1er semestre, semana actual → teoría y laboratorios visibles.
    expect(find.text('1Q'), findsOneWidget);
    expect(find.text('ELM1'), findsWidgets); // Electromagnetismo I (teoría)
    expect(find.text('SSLL'), findsWidgets); // Sistemas Lineales
    expect(find.text('L1'), findsWidgets); // badge de laboratorio
  });

  test('el tema se deriva de la semilla Terra con roles coherentes', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, isNot(theme.colorScheme.secondary));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    expect(theme.useMaterial3, isTrue);
  });

  test('el contraste AA de los roles principales se mantiene en todas las semillas', () {
    final seeds = [
      AppSeeds.terra, AppSeeds.salvia, AppSeeds.miel,
      AppSeeds.rosa, AppSeeds.lavanda, AppSeeds.celeste, AppSeeds.menta,
      AppSeeds.oceano,
    ];
    for (final seed in seeds) {
      for (final theme in [AppTheme.light(seed: seed), AppTheme.dark(seed: seed)]) {
      final scheme = theme.colorScheme;
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
        reason: 'onPrimary/primary (${theme.brightness})',
      );
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(7.0),
        reason: 'onSurface/surface (${theme.brightness})',
      );
      }
    }
  });

  testWidgets('la selección se guarda y sobrevive a un reinicio', (tester) async {
    final repo = InMemoryProfileRepository();
    await pumpApp(tester, repo: repo);
    await completeWizard(tester);
    await settleTaps(tester);

    // La selección del asistente quedó persistida en el repositorio.
    final saved = await repo.load();
    expect(saved, isNotNull);
    expect(saved!.years, [2]);
  });

  testWidgets('calendario y exámenes muestran contenido real', (tester) async {
    await pumpApp(tester);
    await completeWizard(tester);

    // Calendario: mes actual con día de hoy marcado y leyenda.
    await tester.tap(find.text('Calendario'));
    await settleTaps(tester);
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final now = DateTime.now();
    expect(find.text('${months[now.month - 1]} ${now.year}'), findsOneWidget);
    expect(find.text('Festivo'), findsOneWidget); // leyenda

    // Exámenes: hero con el próximo y lista de convocatorias.
    await tester.tap(find.text('Exámenes'));
    await settleTaps(tester);
    expect(find.text('Próximo examen'), findsOneWidget);
    expect(find.text('Electromagnetismo I'), findsWidgets);

    // Convocatoria extraordinaria (junio 2027).
    await tester.tap(find.text('Extraordinaria'));
    await settleTaps(tester);
    await tester.scrollUntilVisible(
      find.text('Estructura de Computadores'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Estructura de Computadores'), findsWidgets);
    expect(find.textContaining('hora por publicar'), findsNothing);
  });

  testWidgets('apariencia: cambiar semilla y modo persiste', (tester) async {
    await pumpApp(tester);
    await completeWizard(tester);
    await tester.tap(find.text('Ajustes'));
    await settleTaps(tester);

    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Color del tema'), findsOneWidget);

    // Cambia la semilla (el estado del provider se actualiza al instante).
    await tester.tap(find.text('Salvia'));
    await settleTaps(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Apariencia')),
    );
    expect(
      container.read(appearanceProvider).valueOrNull?.seed,
      AppearanceSeed.salvia,
    );

    // Cambia el modo a oscuro.
    await tester.ensureVisible(find.text('Oscuro'));
    await tester.pump();
    await tester.tap(find.text('Oscuro'));
    await settleTaps(tester);
    expect(
      container.read(appearanceProvider).valueOrNull?.mode,
      AppearanceMode.dark,
    );

    // La MaterialApp aplica el modo oscuro.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Luminancia relativa WCAG. En Flutter 3.27+ los canales de [Color] son
/// dobles normalizados (0..1).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
