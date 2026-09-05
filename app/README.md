# compas_ucm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Depuración en tu teléfono Android (adb / hot reload)

> ⚠️ **Entorno con /home en solo lectura.** En esta máquina, `/home/snoo/…` está
> montado como *read-only* excepto este proyecto. Flutter, Gradle y adb necesitan
> escribir (cachés, stamps, claves RSA), así que el toolchain usa copias locales
> de escritura en `../.toolkit/` (creadas una vez; borrables, se regeneran
> copiando desde `/home/snoo/Documents/app/env/…` y `~/.gradle`).

### Antes de nada: activar el entorno

```bash
cd /home/snoo/Documents/calendarioucm
source tools/flutter_env.sh        # apunta flutter/java/gradle/adb a .toolkit/
```

Si tu shell es **fish**, en vez del `.sh` usa el cargador equivalente:

```fish
cd /home/snoo/Documents/calendarioucm
source tools/flutter_env.fish
```

### En el teléfono (una sola vez)

1. Ajustes → Acerca del teléfono → toca 7 veces **Número de compilación**
   (se desbloquean las *Opciones de desarrollador*).
2. Ajustes → Opciones de desarrollador → activa **Depuración USB**.
3. Conecta el cable y acepta el diálogo *"¿Permitir depuración USB?"*
   (marca "permitir siempre" para no repetirlo).

### Depurar con hot reload

```bash
tools/phone.sh devices     # ¿ve adb tu teléfono?
tools/phone.sh run         # flutter run: instala la app y queda conectado
```

Con `flutter run` activo: `r` = hot reload, `R` = hot restart, `q` = salir.
Los logs salen en la terminal; alternativamente `tools/phone.sh logs`.

### Solo instalar el APK debug

```bash
tools/phone.sh install      # compila (si hace falta), adb install -r y abre la app
```

### Sin cable (Wireless debugging, Android 11+)

Opciones de desarrollador → **Depuración inalámbrica** → *Emparejar dispositivo
con código*:

```bash
tools/phone.sh pair  <ip-del-teléfono>:<puerto>     # introduce el código de 6 dígitos
tools/phone.sh connect <ip-del-teléfono>:<puerto>   # y ya puedes hacer run/install
```

### Notas

- `applicationId` = `es.compas.ucm`; la activity lanzable es
  `es.compas.ucm.MainActivity` (package Kotlin alineado con el namespace).
- El APK debug se genera en
  `build/app/outputs/flutter-apk/app-debug.apk`.
