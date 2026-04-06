#!/bin/zsh

set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is not installed. Run: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate
xcodebuild \
    -project Peel.xcodeproj \
    -scheme Peel \
    -configuration Debug \
    -derivedDataPath build \
    build
