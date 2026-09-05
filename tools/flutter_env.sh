#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# flutter_env.sh — entornos de compilación locales para Compás UCM.
#
# POR QUÉ EXISTE
#   El home del usuario (/home/snoo/…) está montado en SOLO LECTURA, salvo este
#   proyecto (/home/snoo/Documents/calendarioucm). Flutter/Gradle/Java necesitan
#   escribir (cachés, stamps, claves adb…), así que este script apunta todo a
#   copias de escritura en .toolkit/ dentro del proyecto:
#
#     .toolkit/flutter      copia del SDK de Flutter  (env/flutter)
#     .toolkit/pub-cache    caché de paquetes Dart    (env/.pub-cache)
#     .toolkit/gradle       caché de Gradle/AGP       (~/.gradle)
#     .toolkit/home         HOME virtual (claves adb, prefs de java/flutter)
#
# USO
#   source tools/flutter_env.sh          # desde la raíz del proyecto
#   flutter devices                      # ver teléfono conectado
#   flutter run                          # depuración con hot reload
#   flutter build apk --debug            # o solo generar el APK
# ─────────────────────────────────────────────────────────────────────────────

# Ruta absoluta a la raíz del proyecto (donde viven tools/ y app/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COMPAS_ROOT="$ROOT"

export TOOLKIT="$ROOT/.toolkit"

# SDKs originales (solo lectura, pero se usan tal cual: no necesitan escribir).
export ORIG_ANDROID_SDK="/home/snoo/Documents/app/env/android-sdk"
export ORIG_JAVA_HOME="/home/snoo/Documents/app/env/jdk"

# Flutter: copia de escritura en el toolkit.
export FLUTTER_ROOT="$TOOLKIT/flutter"
export FLUTTER_BIN="$FLUTTER_ROOT/bin"

# Caché de paquetes Dart/pub.
export PUB_CACHE="$TOOLKIT/pub-cache"

# Caché de Gradle (distribución + dependencias AGP/Kotlin).
export GRADLE_USER_HOME="$TOOLKIT/gradle"

# Android SDK y JDK (solo lectura; el build solo los lee).
export ANDROID_HOME="$ORIG_ANDROID_SDK"
export ANDROID_SDK_ROOT="$ORIG_ANDROID_SDK"
export JAVA_HOME="$ORIG_JAVA_HOME"

# HOME virtual de escritura: aquí adb guarda sus claves, java sus prefs y
# flutter su configuración (evita tocar el /home real, que es de solo lectura).
mkdir -p "$TOOLKIT/home/.android" "$TOOLKIT/home/.config" "$TOOLKIT/home/.java"
export HOME="$TOOLKIT/home"
export XDG_CONFIG_HOME="$TOOLKIT/home/.config"
export XDG_CACHE_HOME="$TOOLKIT/home/.cache"
export XDG_DATA_HOME="$TOOLKIT/home/.local/share"

# PATH: flutter, dart, java y adb por delante.
export PATH="$FLUTTER_BIN:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

# Mantén android/local.properties apuntando al Flutter del toolkit
# (si apuntara al SDK original de solo lectura, Gradle fallaría al escribir).
LOCAL_PROPERTIES="$ROOT/app/android/local.properties"
if [ -f "$LOCAL_PROPERTIES" ]; then
  sed -i "s|^flutter.sdk=.*|flutter.sdk=$FLUTTER_ROOT|" "$LOCAL_PROPERTIES" 2>/dev/null || true
  grep -q "^flutter.sdk=" "$LOCAL_PROPERTIES" || echo "flutter.sdk=$FLUTTER_ROOT" >> "$LOCAL_PROPERTIES"
fi

echo "🌱 Entorno Compás UCM listo:"
echo "   flutter : $FLUTTER_ROOT ($("$FLUTTER_BIN/flutter" --version 2>/dev/null | head -1 || echo '? (primera ejecución en curso)'))"
echo "   java    : $JAVA_HOME"
echo "   android : $ANDROID_HOME"
