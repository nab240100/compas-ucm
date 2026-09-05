import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/appearance.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:compas_ucm/features/calendario/calendario_screen.dart';
import 'package:compas_ucm/features/ajustes/ajustes_screen.dart';
import 'package:compas_ucm/features/examenes/examenes_screen.dart';
import 'package:compas_ucm/main.dart';
import 'package:compas_ucm/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

late AcademicData data;

Future<void> _loadFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await loader.load();
}

Future<void> pumpProfile(WidgetTester tester, UserProfile profile) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        academicDataProvider.overrideWith((ref) async => data),
        appearanceRepositoryProvider.overrideWithValue(InMemoryAppearanceRepository()),
          profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository(profile)),
      ],
      child: const CompasUcmApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    data = await AcademicRepository.load();
    await _loadFonts();
  });

  testWidgets('golden calendario mes', (tester) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await pumpProfile(tester, profile);
    await tester.tap(find.text('Calendario'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(CalendarioScreen),
      matchesGoldenFile('goldens/calendario_month.png'),
    );
  });

  testWidgets('golden calendario diciembre (exámenes y vacaciones)', (tester) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await pumpProfile(tester, profile);
    await tester.tap(find.text('Calendario'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Septiembre → diciembre (3 pulsaciones).
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await expectLater(
      find.byType(CalendarioScreen),
      matchesGoldenFile('goldens/calendario_diciembre.png'),
    );
  });

  testWidgets('golden exámenes', (tester) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await pumpProfile(tester, profile);
    await tester.tap(find.text('Exámenes'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(ExamenesScreen),
      matchesGoldenFile('goldens/examenes_list.png'),
    );
  });

  testWidgets('golden ajustes apariencia', (tester) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await pumpProfile(tester, profile);
    await tester.tap(find.text('Ajustes'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(AjustesScreen),
      matchesGoldenFile('goldens/ajustes_apariencia.png'),
    );
  });

}