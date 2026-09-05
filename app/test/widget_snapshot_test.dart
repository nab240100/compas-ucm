import 'dart:convert';

import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:compas_ucm/data/widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

/// El snapshot del widget de Android se genera a partir del perfil: mismo
/// resultado que la proyección del horario en pantalla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AcademicData data;

  setUpAll(() async {
    data = await AcademicRepository.load();
  });

  UserProfile profileOfYear2() => addYearDefaults(data, UserProfile.defaults(), 2);

  test('genera 5 días con las franjas del semestre activo', () {
    final profile = profileOfYear2();
    final snap = buildWidgetSnapshot(data, profile, now: DateTime(2026, 10, 5));
    expect(snap['semester'], 1);
    final days = snap['days'] as List;
    expect(days.length, 5);
    for (final d in days) {
      final day = (d as Map)['day'] as int;
      expect(day, inInclusiveRange(1, 5));
      final slots = d['slots'] as List;
      for (final s in slots.cast<Map>()) {
        expect(s['start'], isA<int>());
        expect(s['end'], isA<int>());
        expect(s['label'], isA<String>());
        expect((s['end'] as int), greaterThan(s['start'] as int));
        // Colores en formato #RRGGBB.
        expect(s['color'], matches(RegExp(r'^#[0-9a-f]{6}$')));
        expect(s['on'], matches(RegExp(r'^#[0-9a-f]{6}$')));
      }
    }
    // 2º curso de 1er semestre tiene clases de verdad.
    final total = days.fold<int>(0, (sum, d) => sum + ((d as Map)['slots'] as List).length);
    expect(total, greaterThan(0));
  });

  test('coincide con la proyección mostrada en pantalla', () {
    final profile = profileOfYear2();
    final snap = buildWidgetSnapshot(data, profile, now: DateTime(2026, 10, 5));
    final projected = projectSlots(data, profile, 1);
    final days = (snap['days'] as List).cast<Map>();
    for (var day = 1; day <= 5; day++) {
      final expected = projected.where((s) => s.day == day).length;
      final actual = (days[day - 1]['slots'] as List).length;
      expect(actual, expected, reason: 'día $day');
    }
  });

  test('el JSON se serializa sin errores', () {
    final profile = profileOfYear2();
    final json = encodeWidgetSnapshot(data, profile, now: DateTime(2026, 10, 5));
    final decoded = jsonDecode(json) as Map;
    expect(decoded['v'], 1);
  });
}
