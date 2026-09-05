/// Derivaciones puras para la pestaña Exámenes: convocatorias del perfil,
/// conflictos, countdowns y claves de recordatorio.
library;

import 'models.dart';
import 'profile.dart';

/// Una fecha concreta de examen de una asignatura.
class ExamItem {
  const ExamItem({
    required this.course,
    required this.call,
    required this.date,
    required this.time,
    required this.room,
    this.dateIndex = 0,
    this.dateCount = 1,
  });

  final Course course;

  /// 'ordinaria' o 'extraordinaria'.
  final String call;
  final DateTime date;
  final String time;
  final String? room;

  /// Índice/total para asignaturas con varias fechas (TFG: 2 presentaciones).
  final int dateIndex;
  final int dateCount;

  bool get timeKnown => time != 'TBD';
  bool get multiDate => dateCount > 1;

  String get label =>
      multiDate ? '${course.name} · fecha ${dateIndex + 1} de $dateCount' : course.name;

  /// Clave estable de recordatorio (por concreción de examen).
  String get reminderKey => '$call|${course.code}|${date.toIso8601String().substring(0, 10)}';
}

/// Todas las convocatorias de las asignaturas seleccionadas, por fecha.
List<ExamItem> examItems(AcademicData data, UserProfile profile, {String? call}) {
  final items = <ExamItem>[];
  for (final code in profile.selectedCourseCodes) {
    final c = data.courseByCode(code);
    for (final (callName, exam) in [
      ('ordinaria', c.examOrdinary),
      ('extraordinaria', c.examExtraordinary),
    ]) {
      if (exam == null || (call != null && call != callName)) continue;
      for (var i = 0; i < exam.dates.length; i++) {
        items.add(ExamItem(
          course: c,
          call: callName,
          date: exam.dates[i],
          time: exam.time,
          room: exam.room,
          dateIndex: i,
          dateCount: exam.dates.length,
        ));
      }
    }
  }
  return items..sort((a, b) => a.date.compareTo(b.date));
}

/// Días con más de un examen (convocatoria del mismo grupo de fechas).
List<List<ExamItem>> examConflicts(List<ExamItem> items) {
  final byDay = <String, List<ExamItem>>{};
  for (final e in items) {
    final key = e.date.toIso8601String().substring(0, 10);
    (byDay[key] ??= []).add(e);
  }
  return [
    for (final g in byDay.values)
      if (g.length > 1) g,
  ];
}

/// Días (sin horas) hasta [date] desde [now].
int daysUntil(DateTime date, DateTime now) {
  final a = DateTime(date.year, date.month, date.day);
  final b = DateTime(now.year, now.month, now.day);
  return a.difference(b).inDays;
}

/// Texto amable de cuenta atrás.
String countdownLabel(int days) {
  if (days < 0) return 'hace ${-days} día${-days == 1 ? '' : 's'}';
  if (days == 0) return 'es hoy';
  if (days == 1) return 'mañana';
  return 'en $days días';
}

/// Nombre corto en español de una fecha.
String esShortDate(DateTime d) {
  const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}
