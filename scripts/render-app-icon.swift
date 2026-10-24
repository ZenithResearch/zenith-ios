import AppKit
import CoreGraphics

// Package existing Zenith artwork; do not redraw or substitute the brand mark.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let image = NSImage(contentsOf: root.appendingPathComponent("Artwork/ZenithLogo.png"))!
let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
precondition(cgImage.width == 1024 && cgImage.height == 1024)
let size = 1024
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8,
  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// iOS app icons must be opaque: fill only the artwork's transparent corners.
context.setFillColor(CGColor(red: 5.0 / 255, green: 8.0 / 255, blue: 7.0 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let png = bitmap.representation(using: .png, properties: [:])!
for destination in ["AppIcon.appiconset/AppIcon.png", "ZenithMark.imageset/ZenithMark.png"] {
  try png.write(to: root.appendingPathComponent("App/Assets.xcassets/" + destination))
}
