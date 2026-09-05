/// Derivaciones puras para la pestaña Calendario: matriz mensual, marcadores
/// por tipo de día y qué cae en un día concreto.
library;

import 'models.dart';
import 'profile.dart';
import 'exam_planning.dart' show ExamItem, examItems;

const List<String> esDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Celda de un mes: día, o null para huecos de alineación.
class MonthCell {
  const MonthCell(this.date, this.inCurrentMonth);

  final DateTime? date;
  final bool inCurrentMonth;
}

/// Matriz 6×7 (lunes primero), siempre con 42 celdas.
List<MonthCell> monthCells(int year, int month) {
  final first = DateTime(year, month, 1);
  final lead = first.weekday - DateTime.monday; // 0..6
  final cells = <MonthCell>[
    for (var i = 0; i < lead; i++) const MonthCell(null, false),
    for (var day = 1; day <= DateTime(year, month + 1, 0).day; day++)
      MonthCell(DateTime(year, month, day), true),
  ];
  while (cells.length < 42) {
    cells.add(const MonthCell(null, false));
  }
  return cells;
}

/// ¿Está [day] dentro del periodo de CLASES (no exámenes) de algún semestre?
bool inClassPeriod(AcademicData data, DateTime day) {
  for (final s in data.semesters) {
    if (!day.isBefore(s.classesStart) && !day.isAfter(s.classesEnd)) return true;
  }
  return false;
}

/// Rango de meses navegable del curso (desde el inicio de clases del 1er
/// semestre hasta el fin de la convocatoria extraordinaria).
({int year, int month}) minMonth(AcademicData data) {
  final d = data.semesters.first.classesStart;
  return (year: d.year, month: d.month);
}

({int year, int month}) maxMonth(AcademicData data) {
  final d = data.extraordinaryExamPeriod.end;
  return (year: d.year, month: d.month);
}

enum DayMarkerType { festivo, noLectivo, vacaciones, welcome, recovery, examen }

class DayMarkers {
  const DayMarkers({required this.events, required this.exams, required this.classDay});

  final List<CalendarEvent> events;
  final List<ExamItem> exams;

  /// Dentro de un periodo de clases (para el subrayado suave).
  final bool classDay;

  List<DayMarkerType> get types => [
        for (final e in events)
          switch (e.type) {
            EventType.festivo => DayMarkerType.festivo,
            EventType.noLectivo => DayMarkerType.noLectivo,
            EventType.vacaciones => DayMarkerType.vacaciones,
            EventType.welcome => DayMarkerType.welcome,
            EventType.recovery => DayMarkerType.recovery,
            EventType.otro => DayMarkerType.festivo,
          },
        if (exams.isNotEmpty) DayMarkerType.examen,
      ];
}

/// Marcadores de un día concreto (eventos + exámenes del perfil + clase).
DayMarkers markersOn(
  AcademicData data,
  UserProfile? profile,
  DateTime day,
) {
  final exams = profile == null
      ? <ExamItem>[]
      : [
          for (final e in examItems(data, profile))
            if (AcademicData.sameDay(e.date, day)) e,
        ];
  return DayMarkers(
    events: data.eventsOn(day),
    exams: exams,
    classDay: inClassPeriod(data, day),
  );
}
