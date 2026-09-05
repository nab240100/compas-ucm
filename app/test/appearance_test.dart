import 'package:compas_ucm/data/appearance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('por defecto: terra + modo sistema', () {
    final prefs = AppearancePrefs.defaults();
    expect(prefs.seed, AppearanceSeed.terra);
    expect(prefs.mode, AppearanceMode.system);
  });

  test('roundtrip JSON conserva las preferencias', () {
    final prefs = AppearancePrefs(seed: AppearanceSeed.miel, mode: AppearanceMode.dark);
    final parsed = AppearancePrefs.fromJson(prefs.toJson());
    expect(parsed, prefs);
  });

  test('valores desconocidos caen a los defaults', () {
    final parsed = AppearancePrefs.fromJson({'seed': 'kraken', 'mode': 'perro'});
    expect(parsed.seed, AppearanceSeed.terra);
    expect(parsed.mode, AppearanceMode.system);
  });

  test('repositorio en memoria guarda y carga', () async {
    final repo = InMemoryAppearanceRepository();
    expect(await repo.load(), isNull);
    await repo.save(const AppearancePrefs(seed: AppearanceSeed.salvia));
    expect((await repo.load())?.seed, AppearanceSeed.salvia);
  });
}
