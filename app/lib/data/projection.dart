/// Proyecciones puras sobre los datos académicos: todo lo que se muestra en
/// horario/calendario se DERIVA de (AcademicData, UserProfile, semestre).
/// Nada de estado duplicado.
library;

import 'models.dart';
import 'profile.dart';

import 'calendar_planning.dart' show inClassPeriod;
export 'calendar_planning.dart' show inClassPeriod;

/// Franjas semanales de [profile] en [semester]: solo asignaturas
/// seleccionadas, y de los laboratorios solo el turno elegido.
List<WeeklySlot> projectSlots(AcademicData data, UserProfile profile, int semester) {
  return [
    for (final s in data.weeklySlots)
      if (s.semester == semester &&
          profile.selectedCourseCodes.contains(s.courseCode) &&
          _matchesTurn(s, profile))
        s,
  ];
}

bool _matchesTurn(WeeklySlot slot, UserProfile profile) {
  if (slot.kind == SlotKind.theory) return true;
  final String? turn = profile.labTurns[slot.courseCode];
  if (turn == null) return false; // sin turno elegido → no mostrar lab
  return slot.group == turn;
}

/// Grupos de laboratorio disponibles para una asignatura (orden del PDF).
List<String> labGroupsOf(AcademicData data, String courseCode) {
  final seen = <String>{};
  final groups = <String>[];
  for (final s in data.weeklySlots) {
    if (s.courseCode == courseCode && s.kind == SlotKind.lab && s.group != null) {
      if (seen.add(s.group!)) groups.add(s.group!);
    }
  }
  return groups;
}

/// Asignaturas de un curso concreto.
List<Course> coursesOfYear(AcademicData data, int year) {
  return [for (final c in data.courses) if (c.belongsToYear(year)) c];
}

/// Asignaturas de todos los cursos seleccionados, sin duplicados
/// (las optativas se ofrecen a 3º y 4º).
List<Course> coursesOfYears(AcademicData data, List<int> years) {
  final seen = <String>{};
  return [
    for (final c in data.courses)
      if (years.any(c.belongsToYear) && seen.add(c.code)) c,
  ];
}

/// Al marcar un curso: añade sus obligatorias y el primer turno disponible
/// de cada laboratorio (si aún no lo estaban).
UserProfile addYearDefaults(AcademicData data, UserProfile draft, int year) {
  final years = [...draft.years, year]..sort();
  final selected = Set<String>.from(draft.selectedCourseCodes)
    ..addAll([for (final c in coursesOfYear(data, year)) if (!c.elective) c.code]);
  final turns = Map<String, String>.from(draft.labTurns);
  for (final code in selected) {
    if (turns.containsKey(code)) continue;
    final first = _firstLab(data, code);
    if (first != null) turns[code] = first;
  }
  return draft.copyWith(years: years, selectedCourseCodes: selected, labTurns: turns);
}

/// Al desmarcar un curso: retira sus obligatorias (las que solo pertenecen
/// a ese curso) y sus turnos; las optativas compartidas se conservan.
UserProfile removeYearDefaults(AcademicData data, UserProfile draft, int year) {
  final toRemove = <String>{
    for (final c in coursesOfYear(data, year))
      if (c.years.length == 1 && c.years.first == year) c.code,
  };
  final selected = Set<String>.from(draft.selectedCourseCodes)
    ..removeAll(toRemove);
  final turns = Map<String, String>.from(draft.labTurns);
  for (final code in toRemove) {
    turns.remove(code);
  }
  return draft.copyWith(
    years: [for (final y in draft.years) if (y != year) y],
    selectedCourseCodes: selected,
    labTurns: turns,
  );
}

/// Rellena los turnos de laboratorio que falten (primera opción disponible).
UserProfile fillMissingLabTurns(AcademicData data, UserProfile profile) {
  final turns = Map<String, String>.from(profile.labTurns);
  var changed = false;
  for (final code in profile.selectedCourseCodes) {
    if (turns.containsKey(code)) continue;
    final first = _firstLab(data, code);
    if (first != null) {
      turns[code] = first;
      changed = true;
    }
  }
  return changed ? profile.copyWith(labTurns: turns) : profile;
}

String? _firstLab(AcademicData data, String courseCode) {
  final groups = labGroupsOf(data, courseCode);
  return groups.isEmpty ? null : groups.first;
}

/// Datos de una semana: lunes a domingo que la contienen.
DateTime mondayOf(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

DateTime sundayOf(DateTime day) => mondayOf(day).add(const Duration(days: 6));

/// Ocupación semanal para el resumen (clases/horas por asignatura).
Map<String, ({int classes, int minutes})> weeklyLoad(List<WeeklySlot> slots) {
  final out = <String, ({int classes, int minutes})>{};
  for (final s in slots) {
    final current = out[s.courseCode] ?? (classes: 0, minutes: 0);
    out[s.courseCode] = (
      classes: current.classes + 1,
      minutes: current.minutes + s.durationMinutes,
    );
  }
  return out;
}

/// Clases del perfil en el día de la semana de [day], ordenadas por hora.
List<WeeklySlot> classesOnWeekday(
    AcademicData data, UserProfile profile, DateTime day, int semester) {
  return [
    for (final s in projectSlots(data, profile, semester))
      if (s.day == day.weekday) s,
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
}

/// ¿El día es laborable académicamente (sin festivo/no lectivo/vacaciones)?
bool isAcademicSchoolDay(AcademicData data, DateTime day) {
  for (final e in data.eventsOn(day)) {
    if (e.type == EventType.festivo ||
        e.type == EventType.noLectivo ||
        e.type == EventType.vacaciones ||
        e.type == EventType.welcome) {
      return false;
    }
  }
  return true;
}

/// Próxima clase del perfil a partir de [now], dentro del semestre activo.
/// Devuelve día y franja, o null si no quedan clases en el periodo.
({DateTime day, WeeklySlot slot})? nextClass(
    AcademicData data, UserProfile profile, DateTime now) {
  final semester = data.semesterAt(now);
  if (semester == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final nowMinutes = now.hour * 60 + now.minute;

  for (var offset = 0; offset <= 21; offset++) {
    final day = today.add(Duration(days: offset));
    if (!inClassPeriod(data, day)) return null;
    if (!isAcademicSchoolDay(data, day)) continue;
    final slots = classesOnWeekday(data, profile, day, semester);
    if (slots.isEmpty) continue;
    if (offset == 0) {
      for (final s in slots) {
        if (s.endMinutes > nowMinutes) return (day: day, slot: s);
      }
      continue; // hoy ya terminó: probamos los siguientes días
    }
    return (day: day, slot: slots.first);
  }
  return null;
}

/// Siguiente periodo de clases tras [from] (para el estado "sin clases").
SemesterInfo? nextClassPeriod(AcademicData data, DateTime from) {
  final day = DateTime(from.year, from.month, from.day);
  for (final s in data.semesters) {
    if (!s.classesStart.isBefore(day)) return s;
  }
  return null;
}

/// Etiqueta de tiempo hasta [minutes] (para la tarjeta "siguiente clase").
String untilLabel(int minutes) {
  if (minutes <= 0) return 'ahora';
  if (minutes < 60) return 'en $minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? 'en $h h' : 'en $h h $m min';
}
