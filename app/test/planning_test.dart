import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/calendar_planning.dart';
import 'package:compas_ucm/data/exam_planning.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AcademicData data;
  late UserProfile year2;

  setUpAll(() async {
    data = await AcademicRepository.load();
    year2 = addYearDefaults(data, UserProfile.defaults(), 2);
  });

  group('exámenes', () {
    test('convocatorias ordinarias de 2º, ordenadas por fecha', () {
      final items = examItems(data, year2, call: 'ordinaria');
      expect(items.length, 9);
      expect(items.first.course.code, '805971'); // Electromagnetismo I, 16-dic
      expect(items.first.date, DateTime(2026, 12, 16));
      expect(items.first.time, '09:30');
      expect(items.last.course.code, '805975'); // Empresa y Gestión, 28-may
      // Todas en orden ascendente.
      for (var i = 0; i < items.length - 1; i++) {
        expect(items[i].date.isAfter(items[i + 1].date), isFalse);
      }
    });

    test('extraordinarias de junio y TFG con doble fecha', () {
      final items = examItems(data, year2, call: 'extraordinaria');
      expect(items.length, 9);
      for (final e in items) {
        expect(e.date.isBefore(DateTime(2027, 6, 14)), isFalse);
      }
      // TFG (4º curso): 27-ene y 07-jun (presentaciones) con hora por publicar.
      final year4 = addYearDefaults(data, UserProfile.defaults(), 4);
      final tfg = [
        for (final e in examItems(data, year4))
          if (e.course.code == '804601' && e.call == 'ordinaria') e,
      ];
      expect(tfg.length, 2);
      expect(tfg.every((e) => !e.timeKnown), isTrue);
      expect(tfg.first.label, 'Trabajo Fin de Grado · fecha 1 de 2');
    });

    test('claves de recordatorio estables y countdown', () {
      final items = examItems(data, year2);
      expect(items.first.reminderKey, 'ordinaria|805971|2026-12-16');
      expect(daysUntil(DateTime(2026, 12, 16), DateTime(2026, 12, 16)), 0);
      expect(daysUntil(DateTime(2026, 12, 17), DateTime(2026, 12, 16)), 1);
      expect(countdownLabel(0), 'es hoy');
      expect(countdownLabel(1), 'mañana');
      expect(countdownLabel(12), 'en 12 días');
      expect(countdownLabel(-3), 'hace 3 días');
    });

    test('conflictos: dos exámenes el mismo día', () {
      final c = data.courseByCode('805960');
      final a = ExamItem(
        course: c, call: 'ordinaria',
        date: DateTime(2027, 1, 14), time: '09:30', room: null,
      );
      final b = ExamItem(
        course: c, call: 'ordinaria',
        date: DateTime(2027, 1, 14), time: '13:00', room: null,
      );
      final conflicts = examConflicts([a, b]);
      expect(conflicts.length, 1);
      expect(conflicts.first.length, 2);
    });

    test('perfil sin asignaturas → sin exámenes', () {
      expect(examItems(data, UserProfile.defaults()), isEmpty);
    });
  });

  group('calendario', () {
    test('matriz de septiembre 2026 (lunes primero)', () {
      final cells = monthCells(2026, 9);
      expect(cells.length, 42);
      expect(cells[0].date, isNull); // el 1 de septiembre cae martes
      expect(cells[1].date, DateTime(2026, 9, 1));
      expect(cells[5].date, DateTime(2026, 9, 5));
      expect(cells[6].date, DateTime(2026, 9, 6)); // domingo
      expect(cells[7].date, DateTime(2026, 9, 7)); // lunes siguiente
    });

    test('rango navegable: septiembre 2026 → julio 2027', () {
      final min = minMonth(data);
      final max = maxMonth(data);
      expect(min, (year: 2026, month: 9));
      expect(max, (year: 2027, month: 7));
    });

    test('marcadores: festivo, día lectivo y examen', () {
      final festivo = markersOn(data, year2, DateTime(2026, 10, 12));
      expect(festivo.events.any((e) => e.name.contains('Fiesta Nacional')), isTrue);
      expect(festivo.types, contains(DayMarkerType.festivo));

      final lectivo = markersOn(data, year2, DateTime(2026, 10, 5));
      expect(lectivo.events, isEmpty);
      expect(lectivo.classDay, isTrue);

      final examen = markersOn(data, year2, DateTime(2026, 12, 16));
      expect(examen.exams.single.course.code, '805971');
      expect(examen.types, contains(DayMarkerType.examen));
    });

    test('día de examen no lectivo: Sin clase pero examen', () {
      final navidad = markersOn(data, year2, DateTime(2026, 12, 25));
      expect(navidad.events, isNotEmpty);
      expect(navidad.classDay, isFalse);
    });
  });
}
