#!/bin/sh
# Adds a glow to Hue Menubar's scene, brightness and colour grids by injecting hue-glow.css/js into
# Raycast's launcher page. Unsupported hack: Raycast updates replace the page, so rerun after updating.
# Usage: ./patch.sh [apply|restore]
set -e
frontend=/Applications/Raycast.app/Contents/Resources/macos-app_RaycastDesktopApp.bundle/Contents/Resources/frontend
page="$frontend/main-window.html"
here=$(cd "$(dirname "$0")" && pwd)

[ -f "$page" ] || { echo "Raycast's launcher page not found at $page" >&2; exit 1; }
touch "$page" 2>/dev/null || {
  echo "macOS blocked changing Raycast. Allow your terminal app in System Settings > Privacy & Security > App Management, then rerun." >&2
  exit 1
}

case "${1:-apply}" in
apply)
  cp "$here/hue-glow.css" "$here/hue-glow.js" "$frontend/"
  grep -q hue-glow "$page" || perl -0pi -e 's#</head>#  <link rel="stylesheet" href="./hue-glow.css">\n    <script defer src="./hue-glow.js"></script>\n  </head>#' "$page"
  echo "Patched." ;;
restore)
  perl -0pi -e 's#\s*<link rel="stylesheet" href="\./hue-glow\.css">\s*<script defer src="\./hue-glow\.js"></script>##' "$page"
  rm -f "$frontend/hue-glow.css" "$frontend/hue-glow.js"
  echo "Restored." ;;
*)
  echo "Usage: $0 [apply|restore]" >&2; exit 64 ;;
esac

# The page is only read when Raycast starts
osascript -e 'quit app "Raycast"' 2>/dev/null || true
sleep 2
open -a Raycast
