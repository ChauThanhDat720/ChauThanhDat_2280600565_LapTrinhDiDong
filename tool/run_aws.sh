#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
if [[ ! -f config/aws.local.json ]]; then
  echo 'Chưa có config/aws.local.json. Làm theo docs/AWS_SETUP.md để triển khai và xuất cấu hình.' >&2
  exit 1
fi
python3 - <<'PYCONFIG'
import json
from pathlib import Path
import sys
sys.path.insert(0, 'tool')
from configure_aws import configuration, MAPPING
config = json.loads(Path('config/aws.local.json').read_text())
if config.get('BACKEND_MODE') != 'aws':
    raise SystemExit('BACKEND_MODE phải là aws khi dùng tool/run_aws.sh.')
configuration([{'OutputKey': output, 'OutputValue': config.get(define)} for output, define in MAPPING.items()])
PYCONFIG
mode="${1:-run}"
if [[ $# -gt 0 ]]; then shift; fi
case "$mode" in
  run) exec flutter run --dart-define-from-file=config/aws.local.json "$@" ;;
  apk) exec flutter build apk --release --target-platform=android-arm64 --dart-define-from-file=config/aws.local.json "$@" ;;
  *) echo 'Cách dùng: bash tool/run_aws.sh [run|apk] [tham số Flutter...]' >&2; exit 2 ;;
esac
