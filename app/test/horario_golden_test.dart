import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/appearance.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:compas_ucm/features/horario/horario_screen.dart';
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

  testWidgets('golden horario año 2', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    debugPrint('PROFILE year2 slots(S1): '
        '${projectSlots(data, profile, 1).map((s) => '${s.day}:${s.start} ${s.courseCode}').join(', ')}');
    await pumpProfile(tester, profile);
    await tester.tap(find.text('Horario'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(HorarioScreen),
      matchesGoldenFile('goldens/horario_year2.png'),
    );
  });

  testWidgets('golden horario solapamiento 3º+4º', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 3º curso con FRC + CAF (labs solapados el miércoles 15:00-17:00)
    // + 4º con Antenas. Perfil "mixto" de varios cursos.
    final p3 = addYearDefaults(data, UserProfile.defaults(), 3);
    final p = p3.copyWith(
      selectedCourseCodes: {'805981', '805980', '805990', '804600'},
      labTurns: {'805981': 'L2', '805980': 'L1', '805990': 'L3', '804600': 'L1'},
    );
    debugPrint('PROFILE overlap slots(S1): '
        '${projectSlots(data, p, 1).map((s) => '${s.day}:${s.start} ${s.courseCode} ${s.group}').join(', ')}');
    await pumpProfile(tester, p);
    await tester.tap(find.text('Horario'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(HorarioScreen),
      matchesGoldenFile('goldens/horario_overlap.png'),
    );
  });
}

