#!/bin/bash
# Сборка и установка FinderTools в /Applications.
set -euo pipefail
cd "$(dirname "$0")"

command -v xcodegen >/dev/null || { echo "Установите XcodeGen: brew install xcodegen"; exit 1; }

xcodegen generate
xcodebuild -project FinderTools.xcodeproj -scheme FinderTools -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- clean build | tail -n 5

APP="build/Build/Products/Release/FinderTools.app"
rm -rf /Applications/FinderTools.app
cp -R "$APP" /Applications/

# Регистрируем и включаем расширение
pluginkit -a /Applications/FinderTools.app/Contents/PlugIns/FinderToolsExtension.appex
pluginkit -e use -i com.example.findertools.extension
killall Finder || true

open /Applications/FinderTools.app
echo "Готово. Нажмите правой кнопкой в любой папке Finder."
