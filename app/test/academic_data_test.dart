import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validación del asset académico generado por
/// `tools/build_academic_json.py`: el parseo es estricto (lanza
/// [FormatException] ante datos mal formados) y [AcademicData.validate]
/// comprueba las invariantes semánticas (solapamientos, grupos, presencia).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AcademicData data;

  setUpAll(() async {
    data = await AcademicRepository.load();
  });

  test('el asset se parsea y la validación semántica está limpia', () {
    expect(data.validate(), isEmpty,
        reason: 'Los datos académicos generados deben ser coherentes: '
            '${data.validate()}');
  });

  test('cantidades esperadas (curso 2026-2027)', () {
    expect(data.meta.academicYear, '2026-2027');
    expect(data.courses.length, 38);
    expect(data.weeklySlots.length, 144);
    expect(data.calendarEvents.length, 13);
    expect(data.semesters.length, 2);
  });

  test('cada slot referencia una asignatura existente y horarios válidos', () {
    for (final slot in data.weeklySlots) {
      expect(() => data.courseByCode(slot.courseCode), returnsNormally,
          reason: 'Slot sin asignatura: $slot');
      expect(slot.day, inInclusiveRange(1, 5));
      expect(slot.startMinutes, lessThan(slot.endMinutes));
      expect(slot.startMinutes, greaterThanOrEqualTo(7 * 60));
      expect(slot.endMinutes, lessThanOrEqualTo(21 * 60));
      expect(slot.semester, inInclusiveRange(1, 2));
    }
  });

  test('las optativas se ofrecen a 3º y 4º', () {
    final electives = data.courses.where((c) => c.elective).toList();
    expect(electives.length, 4);
    for (final e in electives) {
      expect(e.years, [3, 4], reason: '${e.name} debe ser optativa de 3º y 4º');
    }
  });

  test('asignaturas especiales (TFG y prácticas) sin franjas pero con llamadas', () {
    final tfg = data.courseByCode('804601');
    final practicas = data.courseByCode('804611');
    expect(tfg.special, 'tfg');
    expect(practicas.special, 'internship');
    expect(data.slotsOf(tfg.code), isEmpty);
    expect(data.slotsOf(practicas.code), isEmpty);
    // TFG tiene dos fechas de presentación y horas por publicar.
    expect(tfg.examOrdinary!.dates.length, 2);
    expect(tfg.examOrdinary!.timeKnown, isFalse);
  });

  test('Cálculo aparece en 1Q y 2Q según el horario oficial', () {
    final calculo = data.courseByCode('805961');
    expect(calculo.semesters, [1, 2]);
    expect(data.slotsOf(calculo.code).map((s) => s.semester).toSet(), {1, 2});
  });

  test('grupos de laboratorio válidos y por asignatura', () {
    final labSlots = data.weeklySlots.where((s) => s.kind == SlotKind.lab);
    expect(labSlots, isNotEmpty);
    for (final s in labSlots) {
      expect(s.group, isNotNull);
      expect(
        RegExp(r'^L[1-4]( y L[1-4])?$').hasMatch(s.group!),
        isTrue,
        reason: 'Grupo inusual ${s.group} para ${s.courseCode}',
      );
    }
    // Al menos una asignatura con 4 turnos distintos (AdC: L1-L4).
    final adcGroups =
        data.slotsOf('805967').where((s) => s.kind == SlotKind.lab).map((s) => s.group).toSet();
    expect(adcGroups, {'L1', 'L2', 'L3', 'L4'});
  });

  test('eventos de calendario cubren festivos, no lectivos y recuperación', () {
    final types = data.calendarEvents.map((e) => e.type).toSet();
    expect(types.contains(EventType.festivo), isTrue);
    expect(types.contains(EventType.noLectivo), isTrue);
    expect(types.contains(EventType.vacaciones), isTrue);
    expect(types.contains(EventType.recovery), isTrue);
    // Navidad y Semana Santa son rangos.
    final navidad = data.calendarEvents
        .firstWhere((e) => e.type == EventType.vacaciones && e.name.contains('Navidad'));
    expect(navidad.range, isNotNull);
    expect(navidad.includes(DateTime(2026, 12, 25)), isTrue);
    expect(navidad.includes(DateTime(2027, 1, 1)), isTrue);
  });

  test('semestre activo por fecha', () {
    expect(data.semesterAt(DateTime(2026, 10, 1)), 1);
    expect(data.semesterAt(DateTime(2027, 3, 1)), 2);
    expect(data.semesterAt(DateTime(2027, 6, 1)), isNull); // periodo extraordinario
    expect(data.semesterAt(DateTime(2026, 8, 1)), isNull);
  });

  test('periodo extraordinario y aulas de teoría por curso', () {
    expect(data.extraordinaryExamPeriod.start, DateTime(2027, 6, 14));
    expect(data.extraordinaryExamPeriod.end, DateTime(2027, 7, 5));
    expect(data.courseByCode('805960').classroom, 'Aula 2');
    expect(data.courseByCode('805977').classroom, 'Aula M3');
    expect(data.courseByCode('805982').classroom, 'Aula 14');
  });
}
