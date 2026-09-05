import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Semilla cromática del tema.
enum AppearanceSeed {
  /// Sigue el fondo de pantalla del sistema (Material You, Android 12+).
  system,
  terra,
  salvia,
  miel,
  rosa,
  lavanda,
  celeste,
  menta,
  oceano;
}

/// Modo claro/oscuro.
enum AppearanceMode { system, light, dark }

/// Preferencias de apariencia (independientes de la selección académica).
class AppearancePrefs {
  const AppearancePrefs({
    this.seed = AppearanceSeed.terra,
    this.mode = AppearanceMode.system,
  });

  factory AppearancePrefs.defaults() => const AppearancePrefs();

  factory AppearancePrefs.fromJson(Map<String, dynamic> json) {
    return AppearancePrefs(
      seed: AppearanceSeed.values.firstWhere(
        (s) => s.name == json['seed'],
        orElse: () => AppearanceSeed.terra,
      ),
      mode: AppearanceMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => AppearanceMode.system,
      ),
    );
  }

  final AppearanceSeed seed;
  final AppearanceMode mode;

  AppearancePrefs copyWith({AppearanceSeed? seed, AppearanceMode? mode}) =>
      AppearancePrefs(seed: seed ?? this.seed, mode: mode ?? this.mode);

  Map<String, dynamic> toJson() => {'seed': seed.name, 'mode': mode.name};

  @override
  bool operator ==(Object other) =>
      other is AppearancePrefs &&
      other.seed == seed &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(seed, mode);
}

/// Abstraction para poder usar una implementación en memoria en los tests.
abstract class AppearanceRepository {
  Future<AppearancePrefs?> load();

  Future<void> save(AppearancePrefs prefs);
}

class SharedPreferencesAppearanceRepository implements AppearanceRepository {
  static const String _key = 'appearance_v1';

  @override
  Future<AppearancePrefs?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return AppearancePrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AppearancePrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(value.toJson()));
  }
}

class InMemoryAppearanceRepository implements AppearanceRepository {
  InMemoryAppearanceRepository([this._prefs]);

  AppearancePrefs? _prefs;

  @override
  Future<AppearancePrefs?> load() async => _prefs;

  @override
  Future<void> save(AppearancePrefs value) async => _prefs = value;
}
