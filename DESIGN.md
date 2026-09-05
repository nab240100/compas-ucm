# Compás UCM — Diseño de la app

Horario y calendario académico para el Grado en Ingeniería Electrónica de Comunicaciones (UCM, curso 2026-2027).

> Documento de diseño v1 — para iterar con el cliente antes de codificar.

---

## 1. Visión del producto

Una app **offline-first, sin cuenta** que convierte los PDFs oficiales de la facultad
(horarios, calendario, exámenes) en una experiencia personal: eliges tu curso, tus
asignaturas y tu grupo de laboratorio (L1–L4), y la app te muestra:

- **Hoy**: qué clases tienes hoy, cuándo empieza la siguiente, qué cae hoy en el calendario.
- **Horario semanal** y **calendario anual** con festivos, no lectivos, periodos de clases/exámenes.
- **Exámenes** de convocatoria ordinaria y extraordinaria, con recordatorios.
- **Widgets de pantalla de inicio** (opcionales): próxima clase, día de hoy, semana, examen.

Tono: moderno, cálido ("cozy"), Material 3 Expressive, con paleta terrosa y tipografía
redondeada. Español (es-ES) como idioma principal, sin necesidad de red.

## 2. Stack tecnológico

| Capa | Elección | Motivo |
|---|---|---|
| UI | Flutter 3.x + Dart 3 | Entorno ya provisionado (env paths del usuario) |
| Design system | Material 3 + patrones **M3 Expressive** | Última filosofía Material (Google I/O 2025): tonos, formas grandes, movimiento expresivo |
| Estado | Riverpod 3 | Sencillo, testable, sin boilerplate |
| Persistencia | Isar (o Drift) + JSON de datos académicos | Todo local, rápido, sin backend |
| Datos académicos | `assets/data/academic_2026_2027.json` (reescritura del scrape de `ai_studio_code.txt` con validación) | Versionable, actualizable cada curso |
| Notificaciones | `flutter_local_notifications` + `workmanager` | Recordatorios de clase/examen |
| Widgets Android | Glance (Kotlin) en `android/` | Los widgets reales de Android; preview dentro de la app |
| Widgets/estilo | Dynamic color (Material You) con presets cálidos de semilla | Cozy por defecto, wallpaper si el usuario quiere |
| Export | `.ics` + compartir | Google Calendar / otras apps |

## 3. Modelo de datos (dominio)

Basado en los PDFs + scrape; se añaden campos que faltan (créditos, profesor, aula por curso, tipo optativa).

```
AcademicMeta   { version, academicYear "2026-2027", degree, faculty,
                 sourceDocs[], fetchedAt }
Semester       { id: 1|2, classesStart, classesEnd, examPeriod{start,end},
                 gradesDeadline, recoveryDays[] }
CalendarEvent  { name, type: holiday|noLectivo|vacaciones|welcome|recovery,
                 dates[] | start,end, appliesToSemester? }
Course         { code "805960", name "Física I", shortName "Física I",
                 year 1, years [1] (optativas: [3,4]),
                 semester 1|2, credits 6, classroom "Aula 2",
                 teacher?, elective: false, examOrdinary{date,time,room?},
                 examExtraordinary{date,time,room?}, colorHint? }
WeeklySlot     { day Mon..Fri, start "11:30", end "13:30",
                 courseCode, kind: theory|lab, group? "L1"|"L2 y L3",
                 classroom? (override aula teoría) }
LabTurn        (implícito en lab slots: courseCode -> grupos disponibles)
UserProfile    { year 1..4, currentSemester 1|2 (auto por fecha, editable),
                 selectedCourseCodes[], labTurns: {courseCode: "L1"},
                 reminders{classes: on, exams: on, lead: [10m,1d,7d]},
                 themeSeed "terra"|"salvia"|"miel"|wallpaper, darkMode auto }
PersonalEvent  { id, title, date, start?, end?, note, color }  // clase de estudio, cita, etc.
```

Decisiones de modelado clave:

- **Aula de teoría por curso**: el scrape indica "Aula 2 / M3 / 5 / 14" por curso y semestre → se guarda por `Course` (override posible en `WeeklySlot` cuando lab/teoría usan otra aula).
- **Grupos de lab**: `L1..L4` y combinados ("L2 y L3"). El usuario elige **uno por asignatura con labs**; las slots de otros grupos se filtran. Si elige "L2 y L3", el grupo se marca como combinado y ambos días aparecen.
- **Optativas**: bloque propio (`electives_3rd_and_4th_years`) con `years: [3,4]` para que el selector las ofrezca en ambos cursos.
- **TFG / Prácticas**: fechas múltiples y hora "TBD" → se muestran con indicador "hora por publicar" y no generan recordatorio de hora.

## 4. Estructura de la app

```
lib/
  main.dart
  core/            # tema M3, tokens, paletas de curso, formateo de fechas es-ES, a11y
  data/
    models/        # AcademicMeta, Course, WeeklySlot, CalendarEvent, Exam...
    repositories/  # AcademicJsonRepository (asset), SettingsRepository (Isar),
                   # PersonalEventRepository, SnapshotWriter (para widgets)
    parsers/       # parse + validación + tests golden
  features/
    setup/         # wizard primer uso + edición
    hoy/           # pantalla principal "Hoy"
    horario/       # grid semanal, filtros, detalle de clase
    calendario/    # mes anual + leyenda + detalle de día
    examenes/      # convocatorias, countdowns, recordatorios, export ICS
    widgets_preview/  # previsualización de widgets + guía de instalación
    ajustes/       # tema, datos (import/export JSON), copia de seguridad
  widget_android/  # Glance: NextClassWidget, TodayWidget, WeekWidget, ExamWidget
```

## 5. Pantallas y flujos

### 5.1 Onboarding (primer uso, 3 pasos → reutilizable en Ajustes)
1. **Curso**: tarjetas 1º–4º (con foto-token de color distinto por curso).
2. **Asignaturas**: chips agrupados por semestre; contador "6/9 seleccionadas"; optativas marcadas con badge "OPT" y disponibles en 3º y 4º; al seleccionar curso se preseleccionan las obligatorias del semestre.
3. **Grupos de laboratorio**: por cada asignatura con labs, selector L1–L4 (aviso si "L2 y L3" combinado). Opcional: elegir `seed` de color (Terra / Salvia / Miel / Color de fondo) → preview instantáneo.

### 5.2 Navegación principal (5 pestañas)
`Hoy · Horario · Calendario · Exámenes · Ajustes`

**Hoy** (hero de la app)
- Tarjeta grande "Siguiente clase": asignatura, aula, hora, countdown en vivo, botón "ver en horario".
- Línea del tiempo del día (teoría vs labs distinguidos por forma: tarjeta redondeada vs pill con badge de grupo).
- Chip de "hueco libre" entre clases → sugerencia "hueco de 90 min, ideal para estudiar".
- Tarjeta del calendario de hoy: si es festivo/no lectivo/examen → mensaje cálido ("Hoy es no lectivo ☕").
- Próximo examen en el horizonte (si < 30 días).

**Horario**
- Grid semanal (L–V, 08:00–20:30), píldoras por asignatura con su color tonal; labs con badge Ln.
- Línea "ahora" móvil; resaltado del día actual; swipe entre semanas; hoy resalta el semestre activo (auto por fecha: 2-sep…15-dic / 21-ene…7-may).
- Filtros: ocultar labs, solo teoría, semana par/impar (si aplicase), curso/semestre.
- Tap en una clase → bottom sheet: horas, aula, grupo, asignatura, examen asociado, "añadir al calendario" (ICS), "recordarme 10 min antes".
- Vista compacta: lista del día en vez de grid (toggle).

**Calendario**
- Vista mes (agosto 2026 → septiembre 2027, con "hoy" en el centro al abrir).
- Chips de colores por tipo de evento: festivos (dorado), no lectivos (salvia), vacaciones (crema profundo), exámenes (terra), recuperación "R" (lila), periodo de clases (banda superior del mes).
- Botón "saltar a mi periodo de clases"; leyenda siempre visible en lateral.
- Tap en día → sheet: eventos del día + si es día de clase, pequeña miniatura del horario de ese día.
- Componente: grid mensual propio ligero (sin dependencia pesada) o `table_calendar` con estilos M3.

**Exámenes**
- Segmented: Ordinaria / Extraordinaria, agrupados por semestre, ordenados por fecha.
- Cards con countdown ("en 12 días"), aula pendiente/por publicar para TFG/prácticas.
- Toggle de recordatorio por examen (7d / 1d / 2h).
- Botón "Exportar a .ics" (todo o por convocatoria) → share sheet.
- Detección de **solapamiento** de exámenes el mismo día (aviso si ocurre).

**Ajustes**
- Curso, semestre, asignaturas, grupos de lab (reabre wizard en modo edición).
- Tema: presets cálidos, dynamic color (wallpaper), claro/oscuro/auto.
- Notificaciones: clase (10 min antes, por defecto), exámenes, fin de semana resumen semanal.
- Datos: ver fuente/versión (PDFs de la facultad), **importar JSON nuevo curso** (portapapeles o archivo), exportar copia de seguridad, restaurar.
- Widgets: previsualización + "cómo añadir" (long-press en el escritorio).
- Widgets propios dentro de la app para ver cómo se verán.

## 6. Diseño visual (Material 3 Expressive, tono cálido)

### 6.1 Paleta "Cozy by default"
Semillas (se eligen en onboarding), todas con `ColorScheme.fromSeed(..., dynamicSchemeVariant: fidelity)`:

| Seed | Nombre | Uso |
|---|---|---|
| `#B85C38` (terra) | **Terra** — por defecto | exámenes, acento principal |
| `#6F7D5C` (salvia) | **Salvia** | descansos, no lectivos, éxito |
| `#B98A2F` (miel) | **Miel** | festivos, celebraciones |
| Wallpaper | Dynamic color | si el usuario lo activa |

Superficies cálidas (generadas por el esquema tonal M3): fondo `#FBF4EB`-ish (tone 99),
`surfaceContainerHigh` crema tostada, texto tinta `#2E2418` (tone 10). Contraste AA verificado
con los tones del esquema (no hardcodear hex "a mano": se usan los roles M3).

**Paleta de asignaturas**: 8–10 colores *armonizados* con la semilla (tonal 60/80 con texto
tonal 30): cada `Course` recibe `colorHint` determinista (por orden de código/materia) para
que cada asignatura tenga su color estable entre dispositivos, con variante en el grid de
horario.

### 6.2 Tipografía y forma
- Familia empaquetada: **Plus Jakarta Sans** (display/títulos) + Roboto por defecto (cuerpo).
  Atajo amable si se prefiere más redondeza: **Nunito** (incluye `ñ/á/é/í/ó/ú/¿¡`).
- Escala M3 estándar adaptada: títulos redondeados (weight 600–700), cuerpo legible 14–16.
- Formas M3 Expressive: tarjetas 24–28px de radio (contorno "marshmallow"), chips pill,
  `NavigationBar` estándar con indicador de píldora.
- Labs: píldoras con badge circular (L1…) que contrastan con las tarjetas de teoría → lectura
  de un vistazo.

### 6.3 Movimiento (M3 Expressive)
- Transiciones spring con `easeOutBack` sutil (250–350ms) en tarjetas y sheets.
- Cambios de semana en el horario: deslizamiento suave con desvanecido.
- Countdown "latido" sutil en la tarjeta de próxima clase; sin animaciones decorativas
  excesivas (respeto a `reduceMotion`).

### 6.4 Accesibilidad
- Dynamic type (hasta 1.8x), TalkBack semantics por clase/examen, contraste AA en todos los
  textos, targets táctiles ≥ 48dp, `highContrast` con paleta especial, modo diurno/nocturno
  automático sincronizado con el sistema.

## 7. Widgets de pantalla de inicio (opcional)

Implementados con **Glance (Kotlin)** dentro del mismo paquete Android — Flutter no pintará
los widgets; la app escribe un **snapshot JSON** (asignaturas + grupo + próxima clase + exámenes)
en `filesDir` cada vez que cambia la configuración y lo actualiza con `WorkManager` (~cada 30 min
y al abrir la app). El widget lee el snapshot y se auto-renderiza.

| Widget | Tamaño | Contenido |
|---|---|---|
| Próxima clase | 2×2 | Asignatura, hora, aula, "en XX min" |
| Hoy | 4×2 | Timeline compacta del día + próxima clase |
| Semana | 4×4 | Mini grid semanal (píldoras coloreadas, día actual marcado) |
| Examen | 2×2 | Countdown al próximo examen (convocatoria activa) |

Flujo de añadido: Ajustes → Widgets → vista previa → long-press en el escritorio → Compás.

## 8. Características extra (para "feature complete")

1. **Próxima clase + countdown** en Hoy y widget (núcleo de valor diario).
2. **Huecos libres** ("study slots"): detectar y mostrar huecos de la semana.
3. **Resumen semanal** (notificación domingo): nº de clases, labs, exámenes de la semana.
4. **Agenda personal**: añadir clases de estudio/citas, filtradas junto a lo académico; exportar todo a ICS.
5. **Registro de notas** (opcional): nota por asignatura y convocatoria → media ponderada por créditos, progreso por porcentaje del curso completado. Privado y local.
6. **Importación de datos del próximo curso**: pegar JSON (el mismo formato del scrape) o archivo; reconcilia por código de asignatura; mantiene la selección si los códigos coinciden.
7. **Detector de conflictos**: dos exámenes el mismo día, clase solapada teóricamente imposible (datos inmutables), aviso de solapamiento de labs si se eligen grupos cruzados.
8. **Campus en contexto**: aula y edificio en cada clase (mapa de la facultad como fase futura).
9. **Copia de seguridad**: exportar/importar JSON de configuración (sin cuenta, la nube es opcional futura).
10. **Modo "semana de estudio"**: resaltar en el calendario los periodos de examen con cuenta regresiva del inicio del periodo.
11. **i18n**: solo es-ES en v1 (esqueleto ARB listo para en).
12. **Widgets propios + notificaciones** (ya descritos).

## 9. Arquitectura y reglas

- **Offline-first, cero backend**: el JSON académico va en assets; el usuario no necesita cuenta.
- **Capa de datos inmutable**: los modelos del JSON son inmutables; las preferencias del usuario van en Isar.
- **Todo derivable**: el horario semanal es una *proyección* de (year, semester, selectedCourses, labTurns) → se recalcula con selectors de Riverpod; no hay estado duplicado.
- **Validación en parse**: test unitario que verifica que todos los `WeeklySlot.courseCode` existen, fechas dentro de curso, grupos válidos (L1–L4, "L2 y L3"), solapamientos de teoría → el scraper resultante queda blindado por tests.
- **Snapshot para widgets**: única fuente de verdad serializada; los cambios de configuración lo regeneran.
- **Testing**: golden tests para paleta/tema, unit tests de selección→horario, widget tests e integración (wizard).

## 10. Plan de fases

| Fase | Contenido | Entregable |
|---|---|---|
| 0 | Reescritura del JSON académico (completa, validada) + tests | `assets/data/academic_2026_2027.json` |
| 1 | Scaffold Flutter, tema M3 Expressive (presets, paleta de asignaturas, tipografía) | App arranca con tema cozy |
| 2 | Wizard de setup + estado (Riverpod) + selector de labs | Selección completa persistida |
| 3 | Horario (grid + detalles + filtros + "ahora") | Pantalla central usable |
| 4 | Calendario anual + exámenes + countdowns + ICS | Calendario completo |
| 5 | Notificaciones (clase/examen/resumen semanal) | Recordatorio en el mundo real |
| 6 | Widgets Glance (4 widgets) + preview en app | Extensión homescreen |
| 7 | Agenda personal, notas/medias, backup/restore, import próximo curso | Feature complete |
| 8 | Pulido: accesibilidad, dynamic color, i18n, Play Store internal | Release |

Riesgos principales:
- **Widgets Glance** se implementan en Kotlin → dos lenguajes en el repo (contenido: el snapshot JSON los separa limpiamente; el preview en Flutter evita sorpresas).
- **Datos TBD** (TFG/prácticas) → tratados explícitamente en modelo y UI ("hora por publicar").
- **Cambio de curso año a año** → el JSON versionado + importación lo absorbe; la selección sobrevive por `courseCode`.
