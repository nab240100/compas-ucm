/// Modelos del dominio académico de Compás UCM (calendario 2026-2027).
///
/// Inmutables y estrictos: cualquier dato estructuralmente inválido lanza
/// [FormatException] durante el parseo, de modo que un asset corrupto se
/// detecta en los tests y nunca llega a la UI.
library;

/// Versión del esquema JSON que entiende esta app (ver
/// `tools/build_academic_json.py`).
const int academicSchemaVersion = 1;

/// Tipos de evento del calendario académico.
enum EventType {
  festivo,
  noLectivo,
  vacaciones,
  welcome,
  recovery,
  otro;

  static EventType parse(String? raw) {
    return switch (raw) {
      'festivo' => EventType.festivo,
      'noLectivo' => EventType.noLectivo,
      'vacaciones' => EventType.vacaciones,
      'welcome' => EventType.welcome,
      'recovery' => EventType.recovery,
      _ => EventType.otro,
    };
  }
}

enum SlotKind {
  theory,
  lab;

  static SlotKind parse(String? raw) => raw == 'lab' ? SlotKind.lab : SlotKind.theory;
}

/// Rango [start, end] inclusive, ambos días incluidos.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool includes(DateTime day) =>
      !day.isBefore(start) && !day.isAfter(end);

  @override
  String toString() => '$start..$end';
}

/// Metadatos del curso académico (2026-2027, grado, fuentes...).
class AcademicMeta {
  const AcademicMeta({
    required this.academicYear,
    required this.degree,
    required this.university,
    required this.faculty,
    required this.sources,
    required this.generatedAt,
  });

  factory AcademicMeta.fromJson(Map<String, dynamic> json) {
    return AcademicMeta(
      academicYear: json['academicYear'] as String,
      degree: json['degree'] as String,
      university: json['university'] as String,
      faculty: json['faculty'] as String,
      sources: List<String>.from(json['sources'] as List),
      generatedAt: json['generatedAt'] as String,
    );
  }

  final String academicYear;
  final String degree;
  final String university;
  final String faculty;
  final List<String> sources;
  final String generatedAt;
}

/// Datos de un semestre (periodo de clases, exámenes, recuperación...).
class SemesterInfo {
  const SemesterInfo({
    required this.id,
    required this.classesStart,
    required this.classesEnd,
    required this.examPeriod,
    required this.gradesDeadline,
    required this.recoveryDays,
  });

  factory SemesterInfo.fromJson(Map<String, dynamic> json) {
    return SemesterInfo(
      id: json['id'] as int,
      classesStart: DateTime.parse(json['classesStart'] as String),
      classesEnd: DateTime.parse(json['classesEnd'] as String),
      examPeriod: DateRange(
        DateTime.parse((json['examPeriod'] as Map)['start'] as String),
        DateTime.parse((json['examPeriod'] as Map)['end'] as String),
      ),
      gradesDeadline: DateTime.parse(json['gradesDeadline'] as String),
      recoveryDays: [
        for (final d in json['recoveryDays'] as List) DateTime.parse(d as String),
      ],
    );
  }

  final int id;
  final DateTime classesStart;
  final DateTime classesEnd;
  final DateRange examPeriod;
  final DateTime gradesDeadline;
  final List<DateTime> recoveryDays;

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}';

  String get classesLabel => '${_d(classesStart)} – ${_d(classesEnd)}';
  String get examsLabel => '${_d(examPeriod.start)} – ${_d(examPeriod.end)}';
}

/// Evento del calendario anual (festivo, no lectivo, vacaciones...).
class CalendarEvent {
  const CalendarEvent({
    required this.name,
    required this.type,
    required this.dates,
    this.range,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final dates = [for (final d in (json['dates'] as List? ?? [])) DateTime.parse(d as String)];
    DateRange? range;
    if (json['start'] != null && json['end'] != null) {
      range = DateRange(
        DateTime.parse(json['start'] as String),
        DateTime.parse(json['end'] as String),
      );
    }
    if (dates.isEmpty && range == null) {
      throw const FormatException('Evento de calendario sin fechas');
    }
    return CalendarEvent(
      name: json['name'] as String,
      type: EventType.parse(json['type'] as String?),
      dates: dates,
      range: range,
    );
  }

  final String name;
  final EventType type;
  final List<DateTime> dates;
  final DateRange? range;

  bool includes(DateTime day) => dates.any((d) => _sameDay(d, day)) || (range?.includes(day) ?? false);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Convocatoria de examen (ordinaria o extraordinaria).
class ExamCall {
  const ExamCall({required this.dates, required this.time, this.room});

  factory ExamCall.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('Convocatoria nula');
    }
    final single = json['date'] as String?;
    final many = json['dates'] as List?;
    final dates = <DateTime>[
      if (single != null) DateTime.parse(single),
      for (final d in many ?? []) DateTime.parse(d as String),
    ];
    if (dates.isEmpty) {
      throw const FormatException('Convocatoria sin fecha');
    }
    return ExamCall(
      dates: dates,
      time: json['time'] as String? ?? 'TBD',
      room: json['room'] as String?,
    );
  }

  final List<DateTime> dates;
  final String time;
  final String? room;

  bool get timeKnown => time != 'TBD';
  DateTime get primaryDate => dates.first;
}

/// Asignatura (obligatoria u optativa) del grado.
class Course {
  const Course({
    required this.code,
    required this.name,
    required this.years,
    required this.semesters,
    required this.primarySemester,
    required this.elective,
    required this.examOrdinary,
    required this.examExtraordinary,
    this.shortName,
    this.classroom,
    this.special,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final semesters = [for (final s in json['semesters'] as List) s as int];
    if (semesters.isEmpty) {
      throw FormatException('${json['code']}: sin semestres');
    }
    return Course(
      code: json['code'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String?,
      years: [for (final y in json['years'] as List) y as int],
      semesters: semesters,
      primarySemester: json['primarySemester'] as int? ?? semesters.first,
      classroom: json['classroom'] as String?,
      elective: json['elective'] as bool? ?? false,
      special: json['special'] as String?,
      examOrdinary: json['examOrdinary'] == null
          ? null
          : ExamCall.fromJson(json['examOrdinary'] as Map<String, dynamic>),
      examExtraordinary: json['examExtraordinary'] == null
          ? null
          : ExamCall.fromJson(json['examExtraordinary'] as Map<String, dynamic>),
    );
  }

  final String code;
  final String name;
  final String? shortName;

  /// Cursos en los que se imparte (las optativas van en 3º y 4º).
  final List<int> years;

  /// Semestres con actividad oficial (algunas asignaturas aparecen en 1Q y 2Q).
  final List<int> semesters;

  /// Semestre principal de matrícula (el de la lista oficial de exámenes).
  final int primarySemester;

  final String? classroom;
  final bool elective;
  final String? special;
  final ExamCall? examOrdinary;
  final ExamCall? examExtraordinary;

  String get displayName => shortName ?? name;

  bool belongsToYear(int year) => years.contains(year);
}

/// Clase semanal (teoría o laboratorio con grupo L1-L4).
class WeeklySlot {
  const WeeklySlot({
    required this.day,
    required this.start,
    required this.end,
    required this.courseCode,
    required this.kind,
    required this.semester,
    this.group,
    this.classroom,
  });

  factory WeeklySlot.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as int;
    if (day < 1 || day > 5) {
      throw FormatException('Día inválido: $day');
    }
    final semester = json['semester'] as int;
    if (semester < 1 || semester > 2) {
      throw FormatException('Semestre inválido: $semester');
    }
    return WeeklySlot(
      day: day,
      start: json['start'] as String,
      end: json['end'] as String,
      courseCode: json['courseCode'] as String,
      kind: SlotKind.parse(json['kind'] as String?),
      group: json['group'] as String?,
      classroom: json['classroom'] as String?,
      semester: semester,
    );
  }

  /// 1 = lunes ... 5 = viernes.
  final int day;
  final String start;
  final String end;
  final String courseCode;
  final SlotKind kind;
  final String? group;
  final String? classroom;
  final int semester;

  int _parse(String t) {
    final m = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(t);
    if (m == null) {
      throw FormatException('Hora mal formada: $t');
    }
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  int get startMinutes => _parse(start);
  int get endMinutes => _parse(end);
  int get durationMinutes => endMinutes - startMinutes;
  String get startEndLabel => '$start–$end';
}

/// Todo el curso académico cargado desde el asset JSON.
class AcademicData {
  AcademicData({
    required this.meta,
    required this.semesters,
    required this.extraordinaryExamPeriod,
    required this.extraordinaryGradesDeadline,
    required this.calendarEvents,
    required this.courses,
    required this.weeklySlots,
  }) : _coursesByCode = {for (final c in courses) c.code: c};

  factory AcademicData.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int || version != academicSchemaVersion) {
      throw FormatException(
          'Versión de esquema no soportada: $version (esperada $academicSchemaVersion)');
    }

    final semesters = [
      for (final s in json['semesters'] as List)
        SemesterInfo.fromJson(s as Map<String, dynamic>),
    ]..sort((a, b) => a.id.compareTo(b.id));

    final courses = [
      for (final c in json['courses'] as List)
        Course.fromJson(c as Map<String, dynamic>),
    ];

    final slots = [
      for (final s in json['weeklySlots'] as List)
        WeeklySlot.fromJson(s as Map<String, dynamic>),
    ];

    final events = [
      for (final e in json['calendarEvents'] as List)
        CalendarEvent.fromJson(e as Map<String, dynamic>),
    ];

    final problems = <String>[];
    final codes = courses.map((c) => c.code).toSet();
    if (codes.length != courses.length) {
      problems.add('códigos de asignatura duplicados');
    }
    final seen = <String>{};
    for (final s in slots) {
      if (!codes.contains(s.courseCode)) {
        problems.add('slot ${s.courseCode} sin asignatura');
      }
      if (s.startMinutes >= s.endMinutes) {
        problems.add('slot ${s.courseCode} con hora de inicio posterior al fin');
      }
      final key = '${s.courseCode}|${s.day}|${s.start}|${s.end}|${s.group}';
      if (!seen.add(key)) {
        problems.add('slot duplicado: $key');
      }
    }
    if (problems.isNotEmpty) {
      throw FormatException('Datos académicos inválidos:\n- ${problems.join('\n- ')}');
    }

    final extraordinary = json['extraordinaryExamPeriod'] as Map;
    return AcademicData(
      meta: AcademicMeta.fromJson(json['meta'] as Map<String, dynamic>),
      semesters: semesters,
      extraordinaryExamPeriod: DateRange(
        DateTime.parse(extraordinary['start'] as String),
        DateTime.parse(extraordinary['end'] as String),
      ),
      extraordinaryGradesDeadline:
          DateTime.parse(json['extraordinaryGradesDeadline'] as String),
      calendarEvents: events,
      courses: courses,
      weeklySlots: slots,
    );
  }

  final AcademicMeta meta;
  final List<SemesterInfo> semesters;
  final DateRange extraordinaryExamPeriod;
  final DateTime extraordinaryGradesDeadline;
  final List<CalendarEvent> calendarEvents;
  final List<Course> courses;
  final List<WeeklySlot> weeklySlots;
  final Map<String, Course> _coursesByCode;

  Map<String, Course> get coursesByCode => _coursesByCode;

  Course courseByCode(String code) {
    final c = _coursesByCode[code];
    if (c == null) {
      throw StateError('Asignatura desconocida: $code');
    }
    return c;
  }

  List<WeeklySlot> slotsOf(String courseCode) =>
      [for (final s in weeklySlots) if (s.courseCode == courseCode) s];

  /// Semestre activo en [day] (1, 2) o `null` si está fuera de los periodos.
  int? semesterAt(DateTime day) {
    for (final s in semesters) {
      if (!day.isBefore(s.classesStart) && !day.isAfter(s.examPeriod.end)) {
        return s.id;
      }
    }
    return null;
  }

  /// Eventos del calendario que caen en [day].
  List<CalendarEvent> eventsOn(DateTime day) =>
      [for (final e in calendarEvents) if (e.includes(day)) e];

  /// Comprobaciones semánticas sobre los datos ya parseados.
  /// Devuelve la lista de problemas (vacía = todo correcto).
  List<String> validate() {
    final problems = <String>{};

    // 1. La teoría obligatoria no puede solaparse dentro del mismo curso y semestre.
    final theory = [for (final s in weeklySlots) if (s.kind == SlotKind.theory) s];
    for (var i = 0; i < theory.length; i++) {
      final a = theory[i];
      final ca = courseByCode(a.courseCode);
      for (var j = i + 1; j < theory.length; j++) {
        final b = theory[j];
        if (b.day != a.day || b.semester != a.semester) continue;
        final cb = courseByCode(b.courseCode);
        final sameYearGroup = ca.years.length == 1 &&
            cb.years.length == 1 &&
            ca.years.first == cb.years.first;
        if (!sameYearGroup) continue;
        if (a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes) {
          problems.add(
              'Solapamiento de teoría: ${ca.name} vs ${cb.name} (día ${a.day}, $a)');
        }
      }
    }

    // 2. Grupos de laboratorio con formato razonable.
    final groupRe = RegExp(r'^L[1-4]( y L[1-4])?$');
    for (final s in weeklySlots) {
      if (s.kind == SlotKind.lab && s.group != null && !groupRe.hasMatch(s.group!)) {
        problems.add('Grupo de laboratorio inusual: ${s.group}');
      }
    }

    // 3. Toda asignatura no especial tiene presencia en el horario.
    final withSlots = {for (final s in weeklySlots) s.courseCode};
    for (final c in courses) {
      if (c.special == null && !withSlots.contains(c.code)) {
        problems.add('${c.name} no tiene franjas de horario');
      }
    }

    // 4. Las asignaturas tienen como mínimo un curso y un semestre.
    for (final c in courses) {
      if (c.years.isEmpty || c.semesters.isEmpty) {
        problems.add('${c.name} sin curso/semestre');
      }
    }

    return problems.toList();
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
