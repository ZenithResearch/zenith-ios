# Zenith artwork

Use the existing Zenith brand mark, not a newly drawn Z.

Source: ZenithOS revision `516bfffece214a0bc03c819ffd148a7281ea67e0`.

- `ZenithLogo.svg` is copied unchanged from `Resources/ZenithOSIcon.svg`.
- `ZenithLogo.png` is the 1024px image extracted from the matching
  `Resources/ZenithOSIcon.icns` using macOS `sips`.
- The packaging script preserves that image and fills transparent corners with
  its background color for an opaque iOS app icon. The same artwork appears on
  the welcome screen.

Regenerate from the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path /private/tmp/zenith-icon-module-cache \
  scripts/render-app-icon.swift .
```
