#!/bin/sh
# Ad-hoc signed Release build into ./build/Build/Products/Release/
set -e
cd "$(dirname "$0")"
xcodebuild -project huemenubar.xcodeproj -scheme huemenubar -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" build
echo "Built: build/Build/Products/Release/huemenubar.app"
