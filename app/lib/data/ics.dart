/// Generador de archivos .ics (vCalendar 2.0) para exportar convocatorias.
library;

import 'exam_planning.dart';

String _fmt(DateTime d) {
  String p(int v) => v.toString().padLeft(2, '0');
  return '${d.year}${p(d.month)}${p(d.day)}';
}

String _escape(String s) => s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;');

/// ICS con todas las convocatorias pasadas.
String buildExamsIcs(List<ExamItem> items) {
  final buf = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Compás UCM//Exámenes 2026-2027//ES')
    ..writeln('CALSCALE:GREGORIAN')
    ..writeln('METHOD:PUBLISH');

  for (final e in items) {
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:]'), '');
    final start = '${_fmt(e.date)}T${e.time.replaceAll(':', '')}00';
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${e.reminderKey}@compas-ucm')
      ..writeln('DTSTAMP:${stamp.substring(0, 15)}')
      ..writeln('DTSTART;TZID=Europe/Madrid:$start')
      ..writeln('SUMMARY:${_escape(e.label)} (${e.call})')
      ..writeln('DESCRIPTION:${_escape(e.course.code)}');
    if (e.room != null) {
      buf.writeln('LOCATION:${_escape(e.room!)}');
    }
    buf.writeln('END:VEVENT');
  }
  buf.writeln('END:VCALENDAR');
  return buf.toString();
}
