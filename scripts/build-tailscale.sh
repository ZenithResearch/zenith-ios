#!/bin/bash
set -euo pipefail
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
app_root=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$app_root/Artifacts/libtailscale-source"
revision=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["tailscale"]["revision"])' "$app_root/Dependencies.json")
if ! command -v go >/dev/null; then echo 'Install Go 1.27.2 or add its bin directory to PATH.' >&2; exit 2; fi
[[ $(go version) == 'go version go1.27.2 darwin/arm64' ]] || { echo 'Build requires pinned Go 1.27.2 on Apple Silicon.' >&2; exit 2; }
export GOTOOLCHAIN=local GOMODCACHE="$app_root/Artifacts/go-mod" GOCACHE="$app_root/Artifacts/go-cache"
if [ ! -d "$source_dir/.git" ]; then
  git clone https://github.com/tailscale/libtailscale.git "$source_dir"
  git -C "$source_dir" checkout --detach "$revision"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { echo 'libtailscale revision mismatch' >&2; exit 2; }
patch_file="$app_root/scripts/patches/libtailscale-private-logging.patch"
if git -C "$source_dir" diff --quiet; then git -C "$source_dir" apply "$patch_file"; fi
git -C "$source_dir" diff > "$app_root/Artifacts/tailscale-source.diff"
cmp "$patch_file" "$app_root/Artifacts/tailscale-source.diff" || { echo 'Unexpected libtailscale source changes' >&2; exit 2; }
cd "$source_dir"
go mod verify
CGO_ENABLED=1 GOOS=ios GOARCH=arm64 CC="$source_dir/swift/script/clangwrap-ios.sh" go list -deps -json . > "$app_root/Artifacts/tailscale-go-packages.json"
python3 "$app_root/scripts/tailscale-notices.py"
# make uses PWD to locate clang wrappers, so run from the source directory.
make -B c-archive-ios libtailscale_ios_sim_arm64.a
cp libtailscale_ios_sim_arm64.a libtailscale_ios_sim.a
for platform in iOS Simulator; do
  if [ "$platform" = iOS ]; then destination='generic/platform=iOS'; else destination='generic/platform=iOS Simulator'; fi
  xcodebuild -project swift/TailscaleKit.xcodeproj -scheme "TailscaleKit ($platform)" \
    -configuration Release -destination "$destination" -derivedDataPath swift/build \
    ARCHS=arm64 CODE_SIGNING_ALLOWED=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES build
done
output="$app_root/Artifacts/TailscaleKit.xcframework"
if [ -d "$output" ]; then mv "$output" "$app_root/Artifacts/TailscaleKit.previous.$(date +%s).xcframework"; fi
xcodebuild -create-xcframework \
  -framework swift/build/Build/Products/Release-iphoneos/TailscaleKit.framework \
  -framework swift/build/Build/Products/Release-iphonesimulator/TailscaleKit.framework \
  -output "$output"
python3 "$app_root/scripts/tailscale-manifest.py"
