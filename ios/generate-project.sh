#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it with: brew install xcodegen"
  exit 1
fi

cp ../shared/shoplog.html ShopLog/Resources/shoplog.html
xcodegen generate
echo "Generated ios/ShopLog.xcodeproj"

