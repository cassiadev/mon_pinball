// Run from the repository root: swift tool/generate_app_icons.swift
// Native macOS image encoding; no additional packages are required.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let backgroundColor = CGColor(colorSpace: colorSpace, components: [12 / 255, 5 / 255, 64 / 255, 1])!

func load(_ path: String) -> CGImage {
    let url = root.appendingPathComponent(path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Cannot read \(path)")
    }
    return image
}

func render(_ size: Int, opaque: Bool = false, _ draw: (CGContext, CGRect) -> Void) -> CGImage {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: colorSpace,
                            bitmapInfo: alpha.rawValue)!
    context.interpolationQuality = .high
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    if opaque {
        context.setFillColor(backgroundColor)
        context.fill(bounds)
    }
    draw(context, bounds)
    return context.makeImage()!
}

func png(_ image: CGImage) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "PNG encoding failed")
    return data as Data
}

func write(_ data: Data, _ path: String) throws {
    let url = root.appendingPathComponent(path)
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

func save(_ image: CGImage, _ path: String) throws {
    try write(png(image), path)
}

// Keep the supplied file untouched. Normalize its uneven outer canvas without
// stretching the illustration; clear only black connected to the outside edge.
let supplied = load("assets/app_icon/source.png")
precondition(supplied.width == 1254 && supplied.height == 1254)
let tileSize = 1219
let tileContext = CGContext(data: nil, width: tileSize, height: tileSize, bitsPerComponent: 8,
                          bytesPerRow: tileSize * 4, space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
tileContext.draw(supplied, in: CGRect(x: -17, y: -35, width: 1254, height: 1254))
let pixels = tileContext.data!.assumingMemoryBound(to: UInt8.self)
var outside = [Bool](repeating: false, count: tileSize * tileSize)
var queue = [Int]()
func enqueue(_ index: Int) {
    guard !outside[index] else { return }
    let offset = index * 4
    guard max(pixels[offset], pixels[offset + 1], pixels[offset + 2]) <= 10 else { return }
    outside[index] = true
    queue.append(index)
}
for edge in 0..<tileSize {
    enqueue(edge)
    enqueue((tileSize - 1) * tileSize + edge)
    enqueue(edge * tileSize)
    enqueue(edge * tileSize + tileSize - 1)
}
var next = 0
while next < queue.count {
    let index = queue[next]
    next += 1
    let x = index % tileSize, y = index / tileSize
    if x > 0 { enqueue(index - 1) }
    if x + 1 < tileSize { enqueue(index + 1) }
    if y > 0 { enqueue(index - tileSize) }
    if y + 1 < tileSize { enqueue(index + tileSize) }
}
for index in queue {
    for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
}
let source = tileContext.makeImage()!

func fullBleed(_ size: Int) -> CGImage {
    render(size, opaque: true) { context, bounds in context.draw(source, in: bounds) }
}

// The supplied moon, ball and flippers fit within radius 0.52. Include a guard;
// the outer flowers, tassels and gold clouds are decorative maskable background.
let artworkRadius: CGFloat = 0.54
func radialIcon(_ size: Int, radius: CGFloat, opaque: Bool) -> CGImage {
    render(size, opaque: opaque) { context, bounds in
        let side = CGFloat(size) * radius / artworkRadius
        let rect = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2,
                          width: side, height: side)
        context.draw(source, in: rect)
    }
}

func desktopIcon(_ size: Int) -> CGImage {
    render(size) { context, bounds in
        // Traditional desktop icon canvas: 80% tile, transparent outer margin.
        let tile = bounds.insetBy(dx: bounds.width * 0.10, dy: bounds.height * 0.10)
        // The supplied artwork already has its own rounded outline.
        context.draw(source, in: tile)
    }
}

try save(fullBleed(1024), "build/app-icons/master-1024.png")
try save(desktopIcon(1024), "build/app-icons/desktop-1024.png")
try save(fullBleed(512), "build/app-icons/play-store-512.png")

for (density, scale) in [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)] {
    let directory = "android/app/src/main/res/mipmap-\(density)"
    try save(fullBleed(Int(48 * scale)), "\(directory)/ic_launcher.png")
    // 32dp radius leaves a 1dp guard inside Android's 66dp safe circle.
    try save(radialIcon(Int(108 * scale), radius: 32 / 108, opaque: true),
             "\(directory)/ic_launcher_foreground.png")
}

func updateCatalog(_ path: String, desktop: Bool) throws {
    let data = try Data(contentsOf: root.appendingPathComponent("\(path)/Contents.json"))
    let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    var written = Set<String>()
    for image in catalog["images"] as! [[String: String]] {
        guard let filename = image["filename"], written.insert(filename).inserted else { continue }
        let pointSize = Double(image["size"]!.split(separator: "x")[0])!
        let scale = Double(image["scale"]!.dropLast())!
        let pixels = Int((pointSize * scale).rounded())
        try save(desktop ? desktopIcon(pixels) : fullBleed(pixels), "\(path)/\(filename)")
    }
}

try updateCatalog("ios/Runner/Assets.xcassets/AppIcon.appiconset", desktop: false)
try updateCatalog("macos/Runner/Assets.xcassets/AppIcon.appiconset", desktop: true)

// ICO is a small directory of PNG frames, supported by modern Windows.
func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    var little = value.littleEndian
    return withUnsafeBytes(of: &little) { Data($0) }
}
let windowsSizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
let frames = windowsSizes.map { png(desktopIcon($0)) }
var ico = littleEndian(UInt16(0)) + littleEndian(UInt16(1)) + littleEndian(UInt16(frames.count))
var offset = 6 + frames.count * 16
for (size, frame) in zip(windowsSizes, frames) {
    ico.append(contentsOf: [UInt8(size == 256 ? 0 : size), UInt8(size == 256 ? 0 : size), 0, 0])
    ico.append(littleEndian(UInt16(1)))
    ico.append(littleEndian(UInt16(32)))
    ico.append(littleEndian(UInt32(frame.count)))
    ico.append(littleEndian(UInt32(offset)))
    offset += frame.count
}
for frame in frames { ico.append(frame) }
try write(ico, "windows/runner/resources/app_icon.ico")
try save(desktopIcon(512), "linux/runner/resources/app_icon.png")

for size in [192, 512] {
    try save(fullBleed(size), "web/icons/Icon-\(size).png")
    // Web maskable icons guarantee a centered circle of radius 40%.
    try save(radialIcon(size, radius: 0.39, opaque: true), "web/icons/Icon-maskable-\(size).png")
}
try save(fullBleed(180), "web/icons/apple-touch-icon.png")
try save(fullBleed(32), "web/favicon.png")

let iconset = "build/app-icons/MonPinball.iconset"
for points in [16, 32, 128, 256, 512] {
    try save(desktopIcon(points), "\(iconset)/icon_\(points)x\(points).png")
    try save(desktopIcon(points * 2), "\(iconset)/icon_\(points)x\(points)@2x.png")
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", root.appendingPathComponent(iconset).path,
                      "-o", root.appendingPathComponent("build/app-icons/MonPinball.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
precondition(iconutil.terminationStatus == 0, "ICNS generation failed")
print("Generated Android, iOS/iPadOS, macOS, Windows, Linux and web icon assets.")
