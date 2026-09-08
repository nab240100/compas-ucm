import 'package:compas_ucm/data/academic_repository.dart';
import 'package:compas_ucm/data/models.dart';
import 'package:compas_ucm/features/horario/class_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El asset académico ya incluye profesor/despacho por asignatura y la hoja
/// de detalle los muestra al tocar una clase.
void main() {
  late AcademicData data;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    data = await AcademicRepository.load();
  });

  testWidgets('el JSON académico trae profesor y despacho', (tester) async {
    // Cálculo: fila coordinador de la Guía Docente.
    expect(data.courseByCode('805961').profesor, 'Francesco Aprile');
    expect(data.courseByCode('805961').profesorOffice, '03.311.0');
    // Electromagnetismo I: relleno desde su ficha (no estaba en courses.csv).
    expect(data.courseByCode('805971').profesor, 'Sagrario Muñoz San Martín');
    expect(data.courseByCode('805971').profesorOffice, '03.112.0');
  });

  testWidgets('el detalle de una clase muestra horario, aula, profesor y despacho',
      (tester) async {
    final course = data.courseByCode('805961'); // Cálculo
    final slot = data.slotsOf('805961').first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassDetailsSheet(course: course, slot: slot)),
      ),
    );

    expect(find.text(course.name), findsOneWidget);
    expect(find.textContaining(slot.startEndLabel), findsWidgets);
    expect(find.text('Francesco Aprile'), findsOneWidget);
    expect(find.text('03.311.0'), findsOneWidget);
  });
}
