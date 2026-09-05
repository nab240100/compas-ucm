import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Carga y valida los datos académicos empaquetados en el asset JSON.
class AcademicRepository {
  const AcademicRepository._();

  static const String assetPath = 'assets/data/academic_2026_2027.json';

  static Future<AcademicData> load() async {
    final String raw = await rootBundle.loadString(assetPath);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El asset académico no es un objeto JSON');
    }
    return AcademicData.fromJson(decoded);
  }
}
