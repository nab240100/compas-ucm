import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/appearance.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/features/setup/wizard_screen.dart';
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    data = await AcademicRepository.load();
    await _loadFonts();
  });

  testWidgets('golden wizard cursos desplegados', (tester) async {
    tester.view.physicalSize = const Size(640, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academicDataProvider.overrideWith((ref) async => data),
          appearanceRepositoryProvider.overrideWithValue(InMemoryAppearanceRepository()),
          profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository()),
        ],
        child: const CompasUcmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Despliega 3º y marca una asignatura (y otra de 4º para el mix).
    await tester.tap(find.text('Tercer curso'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Teoría de la Comunicación'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cuarto curso'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Redes de computadores'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(WizardScreen),
      matchesGoldenFile('goldens/wizard_year_expanded.png'),
    );
  });
}
