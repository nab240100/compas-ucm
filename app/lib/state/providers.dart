import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/academic_repository.dart';
import '../data/appearance.dart';
import '../data/models.dart';
import '../data/profile.dart';

/// Datos académicos del curso (asset versionado, se carga una sola vez).
final academicDataProvider = FutureProvider<AcademicData>((ref) {
  return AcademicRepository.load();
});

/// Repositorio del perfil (inyectable en tests).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SharedPreferencesProfileRepository();
});

/// Perfil del usuario. `null` = configuración pendiente → asistente.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    return ref.watch(profileRepositoryProvider).load();
  }

  Future<void> save(UserProfile profile) async {
    state = AsyncData(profile);
    await ref.read(profileRepositoryProvider).save(profile);
  }

  Future<void> clear() async {
    await ref.read(profileRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}

/// Repositorio de apariencia (inyectable en tests).
final appearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  return SharedPreferencesAppearanceRepository();
});

/// Preferencias de tema del usuario (semilla + modo claro/oscuro).
final appearanceProvider =
    AsyncNotifierProvider<AppearanceNotifier, AppearancePrefs>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends AsyncNotifier<AppearancePrefs> {
  @override
  Future<AppearancePrefs> build() async {
    return await ref.watch(appearanceRepositoryProvider).load() ??
        AppearancePrefs.defaults();
  }

  Future<void> setSeed(AppearanceSeed seed) async {
    final value = (state.valueOrNull ?? AppearancePrefs.defaults()).copyWith(seed: seed);
    state = AsyncData(value);
    await ref.read(appearanceRepositoryProvider).save(value);
  }

  Future<void> setMode(AppearanceMode mode) async {
    final value = (state.valueOrNull ?? AppearancePrefs.defaults()).copyWith(mode: mode);
    state = AsyncData(value);
    await ref.read(appearanceRepositoryProvider).save(value);
  }
}
