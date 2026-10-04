#!/bin/bash
# Pobiera najnowszą wersję z GitHuba, generuje projekt Xcode i go otwiera.
# Użycie (z dowolnego miejsca): bash ~/FluentNOW/ios/scripts/run-mac.sh
set -euo pipefail

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Brak XcodeGen. Zainstaluj: brew install xcodegen" >&2
  exit 1
fi

echo "→ Pobieram zmiany z GitHuba…"
git -C "$REPO_DIR" pull --ff-only

echo "→ Generuję projekt Xcode…"
cd "$IOS_DIR"
xcodegen generate

echo "→ Otwieram FluentNOW.xcodeproj (uruchom: ⌘R)"
open "$IOS_DIR/FluentNOW.xcodeproj"
