# ─────────────────────────────────────────────────────────────────────────────
# flutter_env.fish — entornos de compilación locales para Compás UCM (fish).
#
# Equivalente a tools/flutter_env.sh pero para la shell fish:
#
#   cd /home/snoo/Documents/calendarioucm
#   source tools/flutter_env.fish
#   flutter devices
#   flutter run
#
# Apunta flutter/java/gradle/adb a las copias de escritura de .toolkit/
# (el /home real está montado en solo lectura).
# ─────────────────────────────────────────────────────────────────────────────

# Ruta absoluta a la raíz del proyecto (donde viven tools/ y app/).
set -gx COMPAS_ROOT (realpath (dirname (status --current-filename))/..)
set -gx TOOLKIT $COMPAS_ROOT/.toolkit

# SDKs originales (solo lectura; se usan tal cual).
set -gx ORIG_ANDROID_SDK /home/snoo/Documents/app/env/android-sdk
set -gx ORIG_JAVA_HOME /home/snoo/Documents/app/env/jdk

# Flutter: copia de escritura en el toolkit.
set -gx FLUTTER_ROOT $TOOLKIT/flutter
set -gx FLUTTER_BIN $FLUTTER_ROOT/bin

# Caché de paquetes Dart/pub y de Gradle.
set -gx PUB_CACHE $TOOLKIT/pub-cache
set -gx GRADLE_USER_HOME $TOOLKIT/gradle

# Android SDK y JDK.
set -gx ANDROID_HOME $ORIG_ANDROID_SDK
set -gx ANDROID_SDK_ROOT $ORIG_ANDROID_SDK
set -gx JAVA_HOME $ORIG_JAVA_HOME

# HOME virtual de escritura (claves adb, prefs de java/flutter).
mkdir -p $TOOLKIT/home/.android $TOOLKIT/home/.config $TOOLKIT/home/.java
set -gx HOME $TOOLKIT/home
set -gx XDG_CONFIG_HOME $TOOLKIT/home/.config
set -gx XDG_CACHE_HOME $TOOLKIT/home/.cache
set -gx XDG_DATA_HOME $TOOLKIT/home/.local/share

# PATH: flutter, dart, java y adb por delante.
set -gx PATH $FLUTTER_BIN $JAVA_HOME/bin $ANDROID_HOME/platform-tools $PATH

# Mantén android/local.properties apuntando al Flutter del toolkit.
set -l props $COMPAS_ROOT/app/android/local.properties
if test -f $props
    sed -i "s|^flutter.sdk=.*|flutter.sdk=$FLUTTER_ROOT|" $props
    if not grep -q "^flutter.sdk=" $props
        echo "flutter.sdk=$FLUTTER_ROOT" >> $props
    end
end

echo "🌱 Entorno Compás UCM listo (fish):"
echo "   flutter : $FLUTTER_ROOT"
echo "   java    : $JAVA_HOME"
echo "   android : $ANDROID_HOME"
