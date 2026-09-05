#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# phone.sh — envía Compás UCM a tu Android por adb y lo depura.
#
# USO (desde la raíz del proyecto, o en cualquier sitio tras `source tools/flutter_env.sh`):
#   tools/phone.sh devices                 # ¿qué dispositivos ve adb?
#   tools/phone.sh run [serial]            # flutter run: instala + depura con hot reload
#   tools/phone.sh install [serial]        # solo instala el APK debug y lo abre
#   tools/phone.sh logs                    # logcat filtrando flutter/errores
#   tools/phone.sh connect <ip>:<puerto>   # adb por Wi-Fi (misma red)
#   tools/phone.sh pair  <ip>:<puerto>     # emparejar Wireless debugging (código de 6 dígitos)
#
# REQUISITOS (teléfono, una vez):
#   1. Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" (activa
#      "Opciones de desarrollador").
#   2. Ajustes → Opciones de desarrollador → activa "Depuración USB".
#   3. Conecta el cable y acepta el diálogo "¿Permitir depuración USB?" de tu teléfono.
#      (Con Wi-Fi: Opciones de desarrollador → "Depuración inalámbrica" → "Emparejar
#      dispositivo con código" y usa `pair` + `connect`.)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Carga el entorno de compilación si aún no se ha hecho (idempotente).
if [ -z "${COMPAS_ROOT:-}" ]; then
  # shellcheck disable=SC1091
  source "$ROOT/tools/flutter_env.sh"
fi

APP="$ROOT/app"
PKG="es.compas.ucm"
ACTIVITY="es.compas.ucm/.MainActivity"
APK="$APP/build/app/outputs/flutter-apk/app-debug.apk"
ADB="$ANDROID_HOME/platform-tools/adb"

android_serials() {
  "$ADB" devices | awk 'NR>1 && $2=="device" {print $1}'
}

pick_serial() {
  local wanted="${1:-}" serials
  serials="$(android_serials)"
  if [ -z "$serials" ]; then
    echo "❌ No hay ningún dispositivo Android conectado." >&2
    echo "   → Conecta el móvil por USB con 'Depuración USB' activada (o usa:" >&2
    echo "     tools/phone.sh pair <ip:puerto>  y  tools/phone.sh connect <ip:puerto>)." >&2
    echo "   → Comprueba con:  tools/phone.sh devices" >&2
    exit 1
  fi
  if [ -n "$wanted" ]; then
    echo "$serials" | grep -qx "$wanted" || {
      echo "❌ El serial '$wanted' no está conectado. Vistos: $serials" >&2
      exit 1
    }
    echo "$wanted"
    return
  fi
  local n
  n="$(echo "$serials" | wc -l)"
  if [ "$n" -gt 1 ]; then
    echo "⚠️  Hay varios dispositivos: $serials" >&2
    echo "   Indica uno: tools/phone.sh run <serial>" >&2
    exit 1
  fi
  echo "$serials"
}

cmd_devices() {
  "$ADB" devices -l
}

cmd_run() {
  local serial
  serial="$(pick_serial "${1:-}")"
  echo "🚀 flutter run en $serial (hot reload: r / hot restart: R / salir: q)…"
  cd "$APP"
  flutter run -d "$serial"
}

cmd_install() {
  local serial
  serial="$(pick_serial "${1:-}")"
  if [ ! -f "$APK" ] || [ "$APK" -ot "$APP/pubspec.yaml" ]; then
    echo "📦 Generando APK debug…"
    (cd "$APP" && flutter build apk --debug)
  fi
  echo "📲 Instalando en $serial…"
  "$ADB" -s "$serial" install -r "$APK"
  echo "▶️  Abriendo Compás UCM…"
  "$ADB" -s "$serial" shell am start -n "$ACTIVITY"
}

cmd_logs() {
  "$ADB" logcat -v time | grep -iE "flutter|compas|AndroidRuntime|FATAL EXCEPTION|ActivityManager.*compas"
}

cmd_connect() {
  [ $# -eq 1 ] || { echo "uso: phone.sh connect <ip:puerto>" >&2; exit 1; }
  "$ADB" connect "$1"
}

cmd_pair() {
  [ $# -eq 1 ] || { echo "uso: phone.sh pair <ip:puerto>   (te pedirá el código de 6 dígitos)" >&2; exit 1; }
  "$ADB" pair "$1"
}

case "${1:-devices}" in
  devices)  cmd_devices ;;
  run)      cmd_run "${2:-}" ;;
  install)  cmd_install "${2:-}" ;;
  logs)     cmd_logs ;;
  connect)  shift; cmd_connect "$@" ;;
  pair)     shift; cmd_pair "$@" ;;
  *) echo "uso: $0 {devices|run [serial]|install [serial]|logs|connect <ip:puerto>|pair <ip:puerto>}" >&2; exit 1 ;;
esac
