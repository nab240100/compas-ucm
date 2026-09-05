/// Instantánea JSON del horario semanal para el widget de Android.
///
/// El widget (Glance/Kotlin) no entiende de Riverpod ni del JSON académico:
/// la app escribe aquí, en SharedPreferences (misma tienda que
/// `shared_preferences`), un objeto pequeño y listo para renderizar — las
/// franjas del perfil proyectadas sobre el semestre activo, con los colores
/// de asignatura ya resueltos. El widget se refresca al abrir la app y al
/// cambiar el perfil (ver HomeShell).
library;

import 'dart:convert';

import 'package:flutter/material.dart' show Color;

import '../core/theme/course_palette.dart';
import 'models.dart';
import 'profile.dart';
import 'projection.dart';

/// Clave de la instantánea en SharedPreferences. En Android la tienda del
/// plugin se llama `FlutterSharedPreferences` y añade el prefijo `flutter.`
/// al nombre de la clave.
const String widgetSnapshotPrefsKey = 'widget_snapshot_v1';

/// Construye el mapa JSON que renderiza el widget de semana.
///
/// El semestre se resuelve igual que en la app: el activo por fecha, y 1 si
/// hoy está fuera de los periodos de clases.
Map<String, Object?> buildWidgetSnapshot(
  AcademicData data,
  UserProfile profile, {
  DateTime? now,
}) {
  final active = data.semesterAt(now ?? DateTime.now()) ?? 1;
  final slots = projectSlots(data, profile, active)
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  final days = <Object?>[
    for (var day = 1; day <= 5; day++)
      {
        'day': day,
        'slots': [
          for (final s in slots)
            if (s.day == day)
              {
                'start': s.startMinutes,
                'end': s.endMinutes,
                'label': data.courseByCode(s.courseCode).displayName,
                'kind': s.kind == SlotKind.lab ? 'lab' : 'theory',
                'group': s.group,
                'color': hex(CoursePalette.containerOf(s.courseCode)),
                'on': hex(CoursePalette.onContainerOf(s.courseCode)),
              },
        ],
      },
  ];

  return {'v': 1, 'semester': active, 'days': days};
}

/// JSON de la instantánea (para guardar en SharedPreferences).
String encodeWidgetSnapshot(AcademicData data, UserProfile profile,
        {DateTime? now}) =>
    jsonEncode(buildWidgetSnapshot(data, profile, now: now));
