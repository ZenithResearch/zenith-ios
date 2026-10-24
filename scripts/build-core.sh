#!/bin/bash
set -euo pipefail
: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
export IPHONEOS_DEPLOYMENT_TARGET=17.0
export MACOSX_DEPLOYMENT_TARGET=13.0
if [ "$#" -ne 1 ]; then echo 'Usage: scripts/build-core.sh /path/to/castalia-wallet' >&2; exit 2; fi
wallet_source=$(cd "$1" && pwd)
app_root=$(cd "$(dirname "$0")/.." && pwd)
expected_wallet_revision=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["wallet"]["revision"])' "$app_root/Dependencies.json")
if [ "$(git -C "$wallet_source" rev-parse HEAD)" != "$expected_wallet_revision" ]; then
  echo "Wallet checkout does not match Dependencies.json" >&2; exit 2
fi
git -C "$wallet_source" diff --exit-code HEAD -- Cargo.toml Cargo.lock crates/castalia-wallet-core crates/castalia-wallet-native crates/castalia-wallet-presentation contracts/portable-web >/dev/null || {
  echo "Wallet build inputs differ from the pinned commit" >&2; exit 2;
}
# Cargo may place scratch output outside the source checkout (for example when
# the source volume is full). Use Cargo's resolved directory for packaging too.
wallet_target_dir=$(cargo metadata --manifest-path "$wallet_source/Cargo.toml" --no-deps --format-version 1 --locked --offline | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_directory"])')
for target in aarch64-apple-darwin aarch64-apple-ios-sim aarch64-apple-ios; do
  cargo build --manifest-path "$wallet_source/Cargo.toml" --locked --offline --release --target "$target" -p castalia-wallet-native
done
output="$app_root/Artifacts/CastaliaWallet.xcframework"
if [ -d "$output" ]; then mv "$output" "$app_root/Artifacts/CastaliaWallet.previous.$(date +%s).xcframework"; fi
xcodebuild -create-xcframework \
  -library "$wallet_target_dir/aarch64-apple-darwin/release/libcastalia_wallet_native.a" -headers "$wallet_source/crates/castalia-wallet-native/include" \
  -library "$wallet_target_dir/aarch64-apple-ios-sim/release/libcastalia_wallet_native.a" -headers "$wallet_source/crates/castalia-wallet-native/include" \
  -library "$wallet_target_dir/aarch64-apple-ios/release/libcastalia_wallet_native.a" -headers "$wallet_source/crates/castalia-wallet-native/include" \
  -output "$output"
python3 "$app_root/scripts/core-manifest.py" "$wallet_source" "$app_root/Artifacts"
