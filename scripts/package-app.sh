#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"${ROOT}/scripts/build-icon.sh"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="${BIN_DIR}/TTSVoice"
RES_BUNDLE="${BIN_DIR}/TTSVoice_TTSVoice.bundle"

OUT="${ROOT}/dist/TTSVoice.app"
rm -rf "${OUT}"
mkdir -p "${OUT}/Contents/MacOS"
mkdir -p "${OUT}/Contents/Resources"

cp "${BIN}" "${OUT}/Contents/MacOS/TTSVoice"
chmod +x "${OUT}/Contents/MacOS/TTSVoice"
cp "${ROOT}/Resources/Info.plist" "${OUT}/Contents/Info.plist"
cp "${ROOT}/Resources/AppIcon.icns" "${OUT}/Contents/Resources/AppIcon.icns"
if [[ -d "${RES_BUNDLE}" ]]; then
	cp -R "${RES_BUNDLE}" "${OUT}/TTSVoice_TTSVoice.bundle"
fi

if command -v codesign >/dev/null 2>&1; then
	codesign --force --deep --sign - "${OUT}" 2>/dev/null || true
	echo "已 codesign（ad-hoc，仅本机运行）"
fi

echo "已生成: ${OUT}"
echo "首次运行: open \"${OUT}\""
