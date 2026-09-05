import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Selección del usuario: cursos, asignaturas cursadas y turnos de
/// laboratorio (ej. "L1", "L2 y L3").
///
/// Soporta cursos mixtos: por ejemplo 6 asignaturas de 3º y 2 de 4º.
class UserProfile {
  const UserProfile({
    required this.years,
    required this.selectedCourseCodes,
    required this.labTurns,
  });

  factory UserProfile.defaults() => const UserProfile(
        years: [],
        selectedCourseCodes: {},
        labTurns: {},
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Migración desde el formato v1 (un único curso).
    final years = json['years'] != null
        ? [for (final y in json['years'] as List) y as int]
        : [json['year'] as int? ?? 1];
    return UserProfile(
      years: years..sort(),
      selectedCourseCodes: {
        for (final c in (json['selectedCourseCodes'] as List? ?? [])) c as String,
      },
      labTurns: {
        for (final e in (json['labTurns'] as Map? ?? {}).entries)
          e.key as String: e.value as String,
      },
    );
  }

  /// Cursos en los que está matriculado (puede haber varios).
  final List<int> years;

  final Set<String> selectedCourseCodes;
  final Map<String, String> labTurns;

  String get yearsLabel =>
      years.isEmpty ? '—' : years.map((y) => '$yº').join(' y ');

  UserProfile copyWith({
    List<int>? years,
    Set<String>? selectedCourseCodes,
    Map<String, String>? labTurns,
  }) {
    return UserProfile(
      years: years == null ? this.years : [...years]..sort(),
      selectedCourseCodes: selectedCourseCodes ?? this.selectedCourseCodes,
      labTurns: labTurns ?? this.labTurns,
    );
  }

  Map<String, dynamic> toJson() => {
        'years': years,
        'selectedCourseCodes': selectedCourseCodes.toList()..sort(),
        'labTurns': labTurns,
      };

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.years.length == years.length &&
      Set.of(other.years).containsAll(years) &&
      other.selectedCourseCodes.length == selectedCourseCodes.length &&
      other.selectedCourseCodes.containsAll(selectedCourseCodes) &&
      other.labTurns.length == labTurns.length &&
      other.labTurns.entries.every((e) => labTurns[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
      Object.hashAll(years),
      Object.hashAll(selectedCourseCodes.toList()..sort()),
      Object.hashAllUnordered(labTurns.entries));
}

/// Abstraction para poder usar una implementación en memoria en los tests.
abstract class ProfileRepository {
  Future<UserProfile?> load();

  Future<void> save(UserProfile profile);

  Future<void> clear();
}

/// Persiste el perfil en SharedPreferences (localStorage en web, DataStore
/// en Android).
class SharedPreferencesProfileRepository implements ProfileRepository {
  static const String _key = 'user_profile_v1';

  @override
  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // perfil corrupto → volver al asistente
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Implementación ligera para tests.
class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this._profile]);

  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;

  @override
  Future<void> clear() async => _profile = null;
}
