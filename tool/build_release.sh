#!/usr/bin/env bash
# 打 release APK（split-per-abi）。
#
# 为什么需要这个脚本：
#   dev_dependencies 里的 integration_test 会被 Flutter 写进
#   android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java，
#   但 release 的 Java 编译路径上没有它的源码，于是
#     package dev.flutter.plugins.integration_test does not exist
#   直接编译失败。这里临时把 integration_test 从 dev_dependencies 摘掉，
#   打完（无论成败）用 trap 恢复 pubspec。
#
# 用法：
#   tool/build_release.sh            # 打三种 ABI
#   tool/build_release.sh --target-platform android-arm64
set -euo pipefail

cd "$(dirname "$0")/.."

: "${FLUTTER:=flutter}"
: "${JAVA_HOME:=/usr/lib/jvm/java-17-openjdk-amd64}"
export JAVA_HOME

BACKUP="$(mktemp)"
cp pubspec.yaml "$BACKUP"

restore() {
  cp "$BACKUP" pubspec.yaml
  rm -f "$BACKUP"
  "$FLUTTER" pub get >/dev/null 2>&1 || true
  echo "== pubspec.yaml 已恢复 =="
}
trap restore EXIT

python3 - <<'PY'
import sys
p = 'pubspec.yaml'
s = open(p).read()
patched = s.replace("  integration_test:\n    sdk: flutter\n", "")
if patched == s:
    sys.exit('pubspec.yaml 里没找到 integration_test 依赖，脚本需要同步更新')
open(p, 'w').write(patched)
print('== 已临时移除 integration_test（仅构建期）==')
PY

"$FLUTTER" pub get
"$FLUTTER" build apk --release --split-per-abi "$@"

OUT=build/app/outputs/flutter-apk
ls -la "$OUT"/*-release.apk
