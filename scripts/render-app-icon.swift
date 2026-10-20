import AppKit
import CoreGraphics

// Code-owned Zenith artwork. Keep the opaque app icon square; iOS supplies its mask.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let size = 1024
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8,
  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.035, green: 0.075, blue: 0.071, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(CGColor(red: 0.447, green: 0.894, blue: 0.784, alpha: 1))
let mark = CGMutablePath()
// A bold Z whose ascending diagonal points toward the upper right.
mark.move(to: CGPoint(x: 250, y: 744))
mark.addLine(to: CGPoint(x: 774, y: 744))
mark.addLine(to: CGPoint(x: 774, y: 626))
mark.addLine(to: CGPoint(x: 434, y: 398))
mark.addLine(to: CGPoint(x: 774, y: 398))
mark.addLine(to: CGPoint(x: 774, y: 280))
mark.addLine(to: CGPoint(x: 250, y: 280))
mark.addLine(to: CGPoint(x: 250, y: 398))
mark.addLine(to: CGPoint(x: 590, y: 626))
mark.addLine(to: CGPoint(x: 250, y: 626))
mark.closeSubpath()
context.addPath(mark)
context.fillPath()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let png = bitmap.representation(using: .png, properties: [:])!
for destination in ["AppIcon.appiconset/AppIcon.png", "ZenithMark.imageset/ZenithMark.png"] {
  try png.write(to: root.appendingPathComponent(destination))
}
