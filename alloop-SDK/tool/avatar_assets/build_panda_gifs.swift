#!/usr/bin/env swift

import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasSize = 512
private let frameCount = 12
private let frameDuration = 0.10

private struct RGBAImage {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

private struct StateSpec {
    let name: String
    let source: String
    let sourceHasChroma: Bool
    let action: String
}

private let states = [
    StateSpec(name: "normal", source: "normal.png", sourceHasChroma: false,
              action: "calm breathing with a periodic soft blink"),
    StateSpec(name: "happy", source: "happy.png", sourceHasChroma: false,
              action: "smiling wave with a gentle buoyant sway"),
    StateSpec(name: "sleepy", source: "sleepy.png", sourceHasChroma: false,
              action: "pillow hug, slow sleepy breathing and a small head bob"),
    StateSpec(name: "stressed", source: "stressed.png", sourceHasChroma: false,
              action: "mild concerned expression with restrained side-to-side tension sway"),
    StateSpec(name: "inactive", source: "inactive.png", sourceHasChroma: false,
              action: "raised-paw neck and upper-body stretch with a gentle release"),
    StateSpec(name: "recovery", source: "recovery.png", sourceHasChroma: false,
              action: "blanket rest with slow relaxed breathing"),
    StateSpec(name: "warning", source: "warning.png", sourceHasChroma: false,
              action: "mild attention pose with visible cooling patch and mouth thermometer"),
    StateSpec(name: "completed_boost", source: "completed_boost.png", sourceHasChroma: false,
              action: "brief smiling celebration with a light bounce and twinkling stars"),
]

private func loadRGBA(_ url: URL) throws -> RGBAImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "PandaAssets", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to load \(url.path)"])
    }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &bytes, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                      CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw NSError(domain: "PandaAssets", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to create RGBA context"])
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return RGBAImage(width: width, height: height, bytes: bytes)
}

private func removeChroma(_ image: inout RGBAImage) {
    for index in stride(from: 0, to: image.bytes.count, by: 4) {
        let red = Int(image.bytes[index])
        let green = Int(image.bytes[index + 1])
        let blue = Int(image.bytes[index + 2])
        let dominance = green - max(red, blue)
        if green > 60 && dominance > 12 {
            let retained = max(0, min(255, 255 - (dominance - 12) * 10))
            if retained == 0 {
                image.bytes[index] = 0
                image.bytes[index + 1] = 0
                image.bytes[index + 2] = 0
                image.bytes[index + 3] = 0
            } else {
                let alpha = Double(retained) / 255.0
                image.bytes[index] = UInt8((Double(red) * alpha).rounded())
                image.bytes[index + 1] = UInt8((Double(min(green, max(red, blue) + 12)) * alpha).rounded())
                image.bytes[index + 2] = UInt8((Double(blue) * alpha).rounded())
                image.bytes[index + 3] = UInt8(retained)
            }
        }
    }
}

private func removeBorderBackground(_ image: inout RGBAImage) {
    let width = image.width
    let height = image.height
    var visited = [Bool](repeating: false, count: width * height)
    var queue = [Int]()
    queue.reserveCapacity(width * 4 + height * 4)

    func isBackground(_ pixel: Int) -> Bool {
        let offset = pixel * 4
        let red = Int(image.bytes[offset])
        let green = Int(image.bytes[offset + 1])
        let blue = Int(image.bytes[offset + 2])
        return min(red, green, blue) >= 224 && max(red, green, blue) - min(red, green, blue) <= 24
    }

    func enqueue(_ pixel: Int) {
        guard pixel >= 0, pixel < visited.count, !visited[pixel], isBackground(pixel) else { return }
        visited[pixel] = true
        queue.append(pixel)
    }

    for x in 0..<width {
        enqueue(x)
        enqueue((height - 1) * width + x)
    }
    for y in 0..<height {
        enqueue(y * width)
        enqueue(y * width + width - 1)
    }

    var cursor = 0
    while cursor < queue.count {
        let pixel = queue[cursor]
        cursor += 1
        let x = pixel % width
        let y = pixel / width
        if x > 0 { enqueue(pixel - 1) }
        if x + 1 < width { enqueue(pixel + 1) }
        if y > 0 { enqueue(pixel - width) }
        if y + 1 < height { enqueue(pixel + width) }
    }
    for pixel in queue {
        let offset = pixel * 4
        image.bytes[offset] = 0
        image.bytes[offset + 1] = 0
        image.bytes[offset + 2] = 0
        image.bytes[offset + 3] = 0
    }
}

private func makeCGImage(_ image: RGBAImage) throws -> CGImage {
    let data = Data(image.bytes) as CFData
    guard let provider = CGDataProvider(data: data),
          let result = CGImage(width: image.width, height: image.height,
                               bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: image.width * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue:
                                   CGImageAlphaInfo.premultipliedLast.rawValue |
                                   CGBitmapInfo.byteOrder32Big.rawValue),
                               provider: provider, decode: nil,
                               shouldInterpolate: true, intent: .defaultIntent) else {
        throw NSError(domain: "PandaAssets", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to create CGImage"])
    }
    return result
}

private func visibleBounds(_ image: RGBAImage) -> CGRect {
    var minX = image.width
    var minY = image.height
    var maxX = 0
    var maxY = 0
    for y in 0..<image.height {
        for x in 0..<image.width where image.bytes[(y * image.width + x) * 4 + 3] > 16 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

private func normalizedMaster(_ image: RGBAImage) throws -> CGImage {
    let sourceImage = try makeCGImage(image)
    let bounds = visibleBounds(image)
    let scale = min(430.0 / bounds.width, 414.0 / bounds.height)
    let targetWidth = bounds.width * scale
    let targetHeight = bounds.height * scale
    let targetX = (CGFloat(canvasSize) - targetWidth) / 2
    let targetY = 476.0 - targetHeight

    guard let cropped = sourceImage.cropping(to: bounds),
          let context = CGContext(data: nil, width: canvasSize, height: canvasSize,
                                  bitsPerComponent: 8, bytesPerRow: canvasSize * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                      CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw NSError(domain: "PandaAssets", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to normalize master"])
    }
    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    context.interpolationQuality = .high
    context.draw(cropped, in: CGRect(x: targetX, y: targetY,
                                     width: targetWidth, height: targetHeight))
    guard let result = context.makeImage() else {
        throw NSError(domain: "PandaAssets", code: 5,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to render normalized master"])
    }
    return result
}

private func drawStar(in context: CGContext, center: CGPoint, radius: CGFloat, alpha: CGFloat) {
    let path = CGMutablePath()
    for point in 0..<10 {
        let angle = -CGFloat.pi / 2 + CGFloat(point) * CGFloat.pi / 5
        let r = point.isMultiple(of: 2) ? radius : radius * 0.43
        let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        point == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(CGColor(red: 1.0, green: 0.73, blue: 0.18, alpha: alpha))
    context.fillPath()
}

private func renderFrame(master: CGImage, state: String, index: Int) throws -> CGImage {
    guard let context = CGContext(data: nil, width: canvasSize, height: canvasSize,
                                  bitsPerComponent: 8, bytesPerRow: canvasSize * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                      CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw NSError(domain: "PandaAssets", code: 6,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to render frame"])
    }
    let phase = 2 * CGFloat.pi * CGFloat(index) / CGFloat(frameCount)
    var xShift: CGFloat = 0
    var yShift: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotation: CGFloat = 0

    switch state {
    case "normal":
        scaleX = 1 + 0.004 * sin(phase)
        scaleY = 1 + 0.009 * sin(phase)
    case "happy":
        yShift = -4 - 4 * sin(phase)
        rotation = 0.010 * sin(phase)
    case "sleepy":
        yShift = 1.8 * sin(phase)
        rotation = 0.007 * sin(phase)
        scaleY = 1 + 0.007 * sin(phase)
    case "stressed":
        xShift = 2.2 * sin(phase * 2)
        rotation = 0.007 * sin(phase * 2)
    case "inactive":
        rotation = 0.012 * sin(phase)
        scaleY = 1 + 0.014 * sin(phase)
        yShift = -2 * sin(phase)
    case "recovery":
        scaleX = 1 + 0.007 * sin(phase)
        scaleY = 1 + 0.010 * sin(phase)
    case "warning":
        yShift = 1.4 * sin(phase)
        rotation = 0.004 * sin(phase)
    case "completed_boost":
        yShift = -5 - 6 * sin(phase)
        rotation = 0.015 * sin(phase)
    default:
        break
    }

    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    context.saveGState()
    context.translateBy(x: 256 + xShift, y: 476 + yShift)
    context.rotate(by: rotation)
    context.scaleBy(x: scaleX, y: scaleY)
    context.translateBy(x: -256, y: -476)
    context.draw(master, in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    context.restoreGState()

    if state == "normal" && (index == 5 || index == 6) {
        context.setFillColor(CGColor(gray: 0.04, alpha: index == 5 ? 0.82 : 1.0))
        context.fillEllipse(in: CGRect(x: 189, y: 291, width: 27, height: 22))
        context.fillEllipse(in: CGRect(x: 297, y: 291, width: 27, height: 22))
        context.setStrokeColor(CGColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 0.92))
        context.setLineWidth(2.4)
        context.setLineCap(.round)
        for x in [194.0, 302.0] {
            context.beginPath()
            context.move(to: CGPoint(x: x, y: 301))
            context.addQuadCurve(to: CGPoint(x: x + 17, y: 301),
                                 control: CGPoint(x: x + 8.5, y: 297))
            context.strokePath()
        }
    }
    if state == "completed_boost" {
        let pulse = 0.70 + 0.30 * (0.5 + 0.5 * sin(phase))
        drawStar(in: context, center: CGPoint(x: 430, y: 126), radius: 11 + 3 * sin(phase), alpha: pulse)
        drawStar(in: context, center: CGPoint(x: 82, y: 164), radius: 8 + 2 * cos(phase), alpha: pulse)
    }

    guard let image = context.makeImage() else {
        throw NSError(domain: "PandaAssets", code: 7,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to create frame image"])
    }
    return image
}

private func savePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw NSError(domain: "PandaAssets", code: 8) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "PandaAssets", code: 9)
    }
}

private func saveGIF(_ frames: [CGImage], to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
    ) else { throw NSError(domain: "PandaAssets", code: 10) }
    CGImageDestinationSetProperties(destination, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ] as CFDictionary)
    let frameProperties: CFDictionary = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: frameDuration,
            kCGImagePropertyGIFUnclampedDelayTime: frameDuration,
        ]
    ] as CFDictionary
    for frame in frames {
        CGImageDestinationAddImage(destination, frame, frameProperties)
    }
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "PandaAssets", code: 11)
    }
}

private func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

private func gifProperties(_ url: URL) throws -> (frames: Int, loop: Int, durations: [Double]) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw NSError(domain: "PandaAssets", code: 12)
    }
    let count = CGImageSourceGetCount(source)
    let top = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
    let gif = top?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    let loop = gif?[kCGImagePropertyGIFLoopCount] as? Int ?? -1
    var durations = [Double]()
    for index in 0..<count {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let frameGIF = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        durations.append(frameGIF?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ??
                         frameGIF?[kCGImagePropertyGIFDelayTime] as? Double ?? -1)
    }
    return (count, loop, durations)
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let packageRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let assetRoot = packageRoot.appendingPathComponent("assets/avatar/panda")
let sourceRoot = assetRoot.appendingPathComponent("source")
let reviewRoot = assetRoot.appendingPathComponent("review_frames")
try FileManager.default.createDirectory(at: reviewRoot, withIntermediateDirectories: true)

var metadataStates = [[String: Any]]()
for state in states {
    var rgba = try loadRGBA(sourceRoot.appendingPathComponent(state.source))
    if state.sourceHasChroma { removeChroma(&rgba) } else { removeBorderBackground(&rgba) }
    let master = try normalizedMaster(rgba)
    let frames = try (0..<frameCount).map { try renderFrame(master: master, state: state.name, index: $0) }
    let gifURL = assetRoot.appendingPathComponent("\(state.name).gif")
    let reviewURL = reviewRoot.appendingPathComponent("\(state.name).png")
    try saveGIF(frames, to: gifURL)
    try savePNG(frames[state.name == "normal" ? 5 : 3], to: reviewURL)
    let validation = try gifProperties(gifURL)
    metadataStates.append([
        "state": state.name,
        "path": "assets/avatar/panda/\(state.name).gif",
        "review_frame": "assets/avatar/panda/review_frames/\(state.name).png",
        "source": "assets/avatar/panda/source/\(state.source)",
        "width": canvasSize,
        "height": canvasSize,
        "frame_count": validation.frames,
        "frame_durations_ms": validation.durations.map { Int(($0 * 1000).rounded()) },
        "nominal_fps": 10,
        "loop": validation.loop,
        "sha256": try sha256(gifURL),
        "action": state.action,
    ])
    print("validated \(state.name): \(validation.frames) frames, loop=\(validation.loop)")
}

let metadata: [String: Any] = [
    "schema_version": 1,
    "canvas": ["width": canvasSize, "height": canvasSize, "baseline_y": 476],
    "character_style": "approved hand-drawn chibi panda from the home-layout reference",
    "gif_loop_semantics": "loop=0 means infinite looping in GIF89a application extension",
    "states": metadataStates,
]
let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
try data.write(to: assetRoot.appendingPathComponent("metadata.json"), options: .atomic)
