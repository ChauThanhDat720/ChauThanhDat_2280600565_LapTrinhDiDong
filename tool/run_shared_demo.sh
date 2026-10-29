#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
action="${1:-help}"
if [ "$#" -gt 0 ]; then shift; fi
case "$action" in
  server)
    HOST="${HOST:-127.0.0.1}" DEMO_MODE=1 node backend/shared/server.js
    ;;
  android)
    if [ "$#" -ne 1 ]; then echo 'Usage: bash tool/run_shared_demo.sh android DEVICE_ID'; exit 1; fi
    if command -v adb >/dev/null 2>&1; then
      adb_bin="$(command -v adb)"
    else
      adb_bin="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
    fi
    "$adb_bin" -s "$1" reverse tcp:3000 tcp:3000
    flutter build apk --debug --dart-define-from-file=config/shared.demo.json
    # Explicit install stops on a signature conflict; never uninstall user data.
    "$adb_bin" -s "$1" install -r build/app/outputs/flutter-apk/app-debug.apk
    flutter run -d "$1" --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
    ;;
  web)
    flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define-from-file=config/shared.demo.json "$@"
    ;;
  *)
    echo 'Start backend: bash tool/run_shared_demo.sh server'
    echo 'Doctor portal: http://localhost:3000/doctor'
    echo 'USB Android:   bash tool/run_shared_demo.sh android DEVICE_ID'
    echo 'Flutter web:   bash tool/run_shared_demo.sh web'
    ;;
esac
