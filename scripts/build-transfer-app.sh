#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift build --product ZenithTransfer
binary_dir=$(swift build --show-bin-path)
app_dir="$project_dir/Artifacts/Zenith Transfer.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$binary_dir/ZenithTransfer" "$app_dir/Contents/MacOS/ZenithTransfer"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ZenithTransfer</string>
<key>CFBundleIdentifier</key><string>ca.zenith.preview.transfer</string>
<key>CFBundleName</key><string>Zenith Transfer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
