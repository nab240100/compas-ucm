import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/exam_planning.dart' show countdownLabel;
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/data/profile.dart';
import 'package:compas_ucm/data/projection.dart';
import 'package:flutter_test/flutter_test.dart';

/// La proyección horario = f(datos, perfil, semestre) es pura: estas pruebas
/// garantizan que la selección del usuario filtra correctamente.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AcademicData data;

  setUpAll(() async {
    data = await AcademicRepository.load();
  });

  test('con año 1 y valores por defecto, el horario de 1Q es el completo', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 1);
    expect(profile.years, [1]);
    expect(profile.selectedCourseCodes.length, 9);
    expect(profile.labTurns['805967'], 'L1'); // Análisis de Circuitos

    final s1 = projectSlots(data, profile, 1);
    // Teoría de Física I (3 huecos), Informática, TyAdD, C.D. y Cálculo (1Q)
    expect(s1.where((s) => s.courseCode == '805960'), isNotEmpty);
    expect(s1.where((s) => s.courseCode == '805961'), isNotEmpty);

    // El lab es solo el turno elegido: AdC no tiene labs en 1Q, TyAdD sí.
    final tyaddLabs = s1.where((s) => s.courseCode == '805964' && s.kind == SlotKind.lab);
    expect(tyaddLabs.map((s) => s.group), everyElement('L1'));
  });

  test('cambiar el turno de laboratorio filtra la franja', () {
    var profile = addYearDefaults(data, UserProfile.defaults(), 1);
    final groups = labGroupsOf(data, '805967');
    expect(groups, ['L1', 'L2', 'L3', 'L4']);

    profile = profile.copyWith(labTurns: {'805967': 'L4'});
    final s2 = projectSlots(data, profile, 2);
    final adcLabs = s2
        .where((s) => s.courseCode == '805967' && s.kind == SlotKind.lab)
        .toList();
    expect(adcLabs.length, 1);
    expect(adcLabs.single.group, 'L4');
    expect(adcLabs.single.day, 5); // L4 cae el viernes 11:30-13:30
  });

  test('los turnos combinados (L2 y L3) aparecen como opción', () {
    expect(labGroupsOf(data, '805964').contains('L2 y L3'), isTrue);
    final profile = addYearDefaults(data, UserProfile.defaults(), 1)
        .copyWith(labTurns: {'805964': 'L2 y L3'});
    final s1 = projectSlots(data, profile, 1);
    final labs = s1
        .where((s) => s.courseCode == '805964' && s.kind == SlotKind.lab)
        .toList();
    expect(labs.any((s) => s.group == 'L2 y L3'), isTrue);
  });

  test('los semestres se proyectan por separado y Cálculo aparece en ambos', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 1);
    final s1 = projectSlots(data, profile, 1);
    final s2 = projectSlots(data, profile, 2);
    expect(s1.where((s) => s.courseCode == '805961'), isNotEmpty);
    expect(s2.where((s) => s.courseCode == '805961'), isNotEmpty);
    expect(s1.where((s) => s.courseCode == '805970'), isEmpty); // 2º curso
  });

  test('las optativas solo se ofrecen en 3º y 4º', () {
    final y2 = coursesOfYear(data, 2);
    final y3 = coursesOfYear(data, 3);
    expect(y2.where((c) => c.elective), isEmpty);
    expect(y3.where((c) => c.elective).map((c) => c.code).toSet(),
        {'806001', '805992', '806000', '804604'});
  });

  test('fillMissingLabTurns rellena huecos sin sobrescribir elecciones', () {
    var profile = addYearDefaults(data, UserProfile.defaults(), 1)
        .copyWith(selectedCourseCodes: {'805960', '805967'});
    profile = fillMissingLabTurns(data, profile);
    expect(profile.labTurns['805967'], isNotNull); // relleno automático
    expect(profile.labTurns.containsKey('805960'), isFalse); // sin labs → nada
  });

  test('cursos mixtos: 6 de 3º y 2 de 4º se proyectan juntos', () {
    var profile = addYearDefaults(data, UserProfile.defaults(), 3);
    // 6 asignaturas de 3º (4 obligatorias de 1Q + 2 de 2Q) y 2 de 4º.
    profile = profile.copyWith(
      selectedCourseCodes: {'805978', '805979', '805980', '805981', '805982', '805984', '804600', '804587'},
      labTurns: {
        '805980': 'L1', '805981': 'L1', '805982': 'L1',
        '804600': 'L1', '804587': 'L1',
      },
      years: [3, 4],
    );
    expect(profile.years, [3, 4]);

    final s1 = projectSlots(data, profile, 1);
    // Teoría de ambos cursos en 1Q.
    expect(s1.where((s) => s.courseCode == '805978'), isNotEmpty); // TdC (3º)
    expect(s1.where((s) => s.courseCode == '804600'), isNotEmpty); // RdC (4º)
    expect(s1.where((s) => s.courseCode == '804587'), isNotEmpty); // DSD (4º)

    final s2 = projectSlots(data, profile, 2);
    expect(s2.where((s) => s.courseCode == '805982'), isNotEmpty); // EA (3º 2Q)
    expect(s2.where((s) => s.courseCode == '805984'), isNotEmpty); // CdS (3º 2Q)
  });

  test('desmarcar un curso retira solo sus obligatorias', () {
    var profile = addYearDefaults(data, UserProfile.defaults(), 3);
    profile = addYearDefaults(data, profile, 4);
    expect(profile.years, [3, 4]);
    expect(profile.selectedCourseCodes.contains('805978'), isTrue); // TdC (3º)

    // Una optativa (compartida 3º/4º) añadida a mano debe conservarse.
    profile = profile.copyWith(
      selectedCourseCodes: {...profile.selectedCourseCodes, '806001'},
    );

    profile = removeYearDefaults(data, profile, 3);
    expect(profile.years, [4]);
    expect(profile.selectedCourseCodes.contains('805978'), isFalse);
    // Las optativas compartidas (years [3,4]) se conservan si estaban.
    expect(profile.selectedCourseCodes.contains('806001'), isTrue); // BioIng
    expect(profile.selectedCourseCodes.contains('804600'), isTrue); // RdC (4º)
  });

  test('nextClass: sábado sin clases → lunes siguiente', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    final saturday = DateTime(2026, 9, 5, 12, 0); // sábado
    final next = nextClass(data, profile, saturday)!;
    expect(next.slot.courseCode, '805970'); // Sistemas Lineales (lun 09:30 lab)
    expect(next.day, DateTime(2026, 9, 7));
    // El countdown de días: 2 días (el 7 de sep respecto al 5).
    expect(countdownLabel(2), 'en 2 días');
  });

  test('nextClass: el lunes antes de la clase devuelve la primera aún no acabada', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    // Lunes 14:00 → la 09:30 (lab SSLL) ya pasó; la siguiente es ELM1 15:00.
    final monday = DateTime(2026, 9, 7, 14, 0);
    final next = nextClass(data, profile, monday)!;
    expect(next.day, DateTime(2026, 9, 7));
    expect(next.slot.start, '15:00');
  });

  test('nextClass: los festivos se saltan (12 oct lunes → clase el 13)', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    // 2026-10-12 es lunes festivo; el martes 13 hay clase (SSLL 15:00).
    final festivo = DateTime(2026, 10, 12, 20, 0);
    final next = nextClass(data, profile, festivo)!;
    expect(next.day, DateTime(2026, 10, 13));
  });

  test('nextClass: en periodo de exámenes no hay clases', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 2);
    final jan = DateTime(2027, 1, 10, 12, 0); // exam period 1Q
    expect(nextClass(data, profile, jan), isNull);
    final period = nextClassPeriod(data, jan);
    expect(period!.id, 2); // el siguiente periodo es el 2º semestre
  });

  test('untilLabel con formato amable', () {
    expect(untilLabel(0), 'ahora');
    expect(untilLabel(45), 'en 45 min');
    expect(untilLabel(60), 'en 1 h');
    expect(untilLabel(135), 'en 2 h 15 min');
  });

  test('isAcademicSchoolDay: festivo y no lectivo no son días de clase', () {
    expect(isAcademicSchoolDay(data, DateTime(2026, 10, 12)), isFalse); // Fiesta Nacional
    expect(isAcademicSchoolDay(data, DateTime(2026, 10, 29)), isFalse); // no lectivo
    expect(isAcademicSchoolDay(data, DateTime(2026, 12, 25)), isFalse); // Navidad
    expect(isAcademicSchoolDay(data, DateTime(2026, 9, 8)), isTrue); // martes normal
    expect(isAcademicSchoolDay(data, DateTime(2026, 12, 9)), isTrue); // día R (recuperación)
  });

  test('weeklyLoad suma clases y minutos por asignatura', () {
    final profile = addYearDefaults(data, UserProfile.defaults(), 1);
    final s1 = projectSlots(data, profile, 1);
    final load = weeklyLoad(s1);
    final fisica = load['805960']!;
    expect(fisica.classes, 3); // lunes 11:30, miércoles 12:30, viernes 12:30
    expect(fisica.minutes, 6 * 60);
  });
}
