#!/bin/zsh
# Construit mCASTING.app (app + serveur MCP embarqué), la signe (certificat local stable) puis l'installe dans
# ~/Applications/Applications Personnelles. DEV=1 : version de développement « mCASTING Dev » (identifiant …​.dev, données séparées,
# jamais installée). NO_INSTALL=1 : ne pas installer.
set -euo pipefail
cd "$(dirname "$0")"
NAME="mCASTING"; BID="fr.stephan.mcasting"
[ -n "${DEV:-}" ] && { NAME="mCASTING Dev"; BID="fr.stephan.mcasting.dev"; NO_INSTALL=1; }
APP="$NAME.app"; DEST="$HOME/Applications/Applications Personnelles"
rm -rf "$APP" build; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos15 -o "$APP/Contents/MacOS/mCASTING" Sources/Core/*.swift Sources/App/*.swift
swiftc -O -swift-version 5 -target arm64-apple-macos15 -o "$APP/Contents/MacOS/mcasting-mcp" Sources/Core/*.swift Sources/MCP/main.swift
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
mkdir -p "$APP/Contents/Resources/skill/mcasting" && cp Resources/skill/mcasting/SKILL.md "$APP/Contents/Resources/skill/mcasting/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BID" -c "Set :CFBundleDisplayName $NAME" -c "Set :CFBundleName $NAME" "$APP/Contents/Info.plist"
for l in fr en es it; do mkdir -p "$APP/Contents/Resources/$l.lproj"; cp "Resources/$l.lproj/InfoPlist.strings" "$APP/Contents/Resources/$l.lproj/"; done
rm -rf build
SIGN="/Volumes/SKYRIM/TOOLS/MAC/_tools/sign_app.sh"
if [ -x "$SIGN" ]; then "$SIGN" "$APP"; else codesign --force --deep -s - "$APP"; fi
if [ -z "${NO_INSTALL:-}" ]; then
  mkdir -p "$DEST"; pkill -x mCASTING 2>/dev/null || true
  rm -rf "$DEST/$APP"; cp -R "$APP" "$DEST/$APP"; echo "Installée : $DEST/$APP"
fi
echo "OK : $APP"
