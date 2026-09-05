# Compás UCM

Horario y calendario académico del Grado en Ingeniería Electrónica de
Comunicaciones (UCM) — app **Flutter** offline-first (sin cuenta) con widget de
Android para el horario semanal.

## Estructura

- `app/` — la app Flutter (`lib/`, tests, carpeta Android).
- `tools/` — utilidades: `flutter_env.sh`/`flutter_env.fish` (toolchain local),
  `phone.sh` (adb), `build_academic_json.py`, `generate_icons.py`.
- `DESIGN.md` — diseño y arquitectura (v1).
- `ai_studio_code.txt` — volcado original usado para montar los datos.
- PDFs oficiales de la facultad — fuente de los datos académicos.

## Requisitos

- Flutter 3.47+ / Dart 3.13
- Android SDK + JDK 17

### Nota sobre el entorno de desarrollo

En esta máquina `/home` está montado en **solo lectura** salvo este proyecto;
por eso existe `tools/flutter_env.{sh,fish}`, que apunta Flutter/Gradle/adb a
copias de escritura en `../.toolkit/` (ignoradas por git, regenerables).

```bash
cd <raíz-del-repo>
source tools/flutter_env.sh        # (en fish: source tools/flutter_env.fish)
cd app
flutter pub get
flutter test
flutter build apk --debug
```

## Datos académicos

`app/assets/data/academic_2026_2027.json` se genera/valida con
`tools/build_academic_json.py` a partir de los PDFs oficiales de la facultad.
Verifica los festivos/no lectivos contra el calendario oficial antes de cada
curso; el PDF codifica los días en **colores** (texto rojo, fondos, "R" azul)
que la extracción por visión tiende a perder.

## Widget de horario (Android)

La app escribe una instantánea del horario del perfil en SharedPreferences
(`app/lib/data/widget_snapshot.dart`) y el widget la lee (carpeta
`app/android/.../widgets/`) para pintar la semana L–V de 08:00 a 20:00.
Añadir: mantener pulsado el escritorio → Widgets → Compás UCM → *Horario
semanal*.

## Licencia / aviso

Los calendarios y horarios proceden de documentos oficiales publicados por la
facultad (consulta sus condiciones antes de redistribuir). El resto del código
de esta app es privado del autor hasta que se decida una licencia.
