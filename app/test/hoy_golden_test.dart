import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/appearance.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:compas_ucm/features/hoy/hoy_screen.dart';
import 'package:compas_ucm/main.dart';
import 'package:compas_ucm/state/providers.dart';
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

/// Goldens con fecha congelada (09-2026) para que sean reproducibles.
Future<void> pumpWithNow(WidgetTester tester, DateTime now, UserProfile profile) async {
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

  testWidgets('golden hoy con siguiente clase', (tester) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await pumpWithNow(tester, DateTime(2026, 9, 5, 12), profile);

    await expectLater(
      find.byType(HoyScreen),
      matchesGoldenFile('goldens/hoy_next_class.png'),
    );
  });

  testWidgets('golden hoy oscuro con semilla miel', (tester) async {
    tester.view.physicalSize = const Size(596, 1073);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academicDataProvider.overrideWith((ref) async => data),
          profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository(profile)),
          appearanceRepositoryProvider.overrideWithValue(InMemoryAppearanceRepository(
            const AppearancePrefs(seed: AppearanceSeed.miel, mode: AppearanceMode.dark),
          )),
        ],
        child: const CompasUcmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(HoyScreen),
      matchesGoldenFile('goldens/hoy_dark_miel.png'),
    );
  });


  testWidgets('golden hoy oscuro con semilla oceano', (tester) async {
    tester.view.physicalSize = const Size(596, 1073);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academicDataProvider.overrideWith((ref) async => data),
          profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository(profile)),
          appearanceRepositoryProvider.overrideWithValue(InMemoryAppearanceRepository(
            const AppearancePrefs(seed: AppearanceSeed.oceano, mode: AppearanceMode.dark),
          )),
        ],
        child: const CompasUcmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(HoyScreen),
      matchesGoldenFile('goldens/hoy_dark_oceano.png'),
    );
  });

}