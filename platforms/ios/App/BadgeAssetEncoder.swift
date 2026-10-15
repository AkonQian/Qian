import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct BadgePreparedAsset: Sendable {
    let data: Data
    let format: UInt8
    let detail: String
}

enum BadgeAssetEncoder {
    struct Failure: LocalizedError {
        let text: String
        var errorDescription: String? { text }
    }

    static func prepare(_ data: Data) throws -> BadgePreparedAsset {
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw Failure(text: "请选择小于 20 MB 的图片或 GIF。")
        }
        let type = CGImageSourceGetType(source).map { $0 as String }
        if type == UTType.gif.identifier, CGImageSourceGetCount(source) > 1 {
            return try prepareGIF(source)
        }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 466
        ] as CFDictionary), let rendered = square(image, side: 466) else {
            throw Failure(text: "无法读取这张图片，请换一张。")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Failure(text: "无法处理图片。")
        }
        CGImageDestinationAddImage(destination, rendered, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= 512 * 1024 else {
            throw Failure(text: "压缩后的图片仍过大，请换一张。")
        }
        return BadgePreparedAsset(data: output as Data, format: 1, detail: "静态图片 · 466 × 466")
    }

    private static func square(_ image: CGImage, side: Int) -> CGImage? {
        guard image.width > 0, image.height > 0,
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)))
        let scale = max(Double(side) / Double(image.width), Double(side) / Double(image.height))
        let width = Double(image.width) * scale, height = Double(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (Double(side) - width) / 2, y: (Double(side) - height) / 2,
                                       width: width, height: height))
        return context.makeImage()
    }

    private static func prepareGIF(_ source: CGImageSource) throws -> BadgePreparedAsset {
        let count = CGImageSourceGetCount(source)
        guard count <= 500 else { throw Failure(text: "GIF 帧数过多，请先裁短到 15 秒以内。") }
        var ends: [Double] = [], duration = 0.0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as NSDictionary?
            let gif = properties?[kCGImagePropertyGIFDictionary] as? NSDictionary
            let raw = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            duration += max(0.02, raw.isFinite ? raw : 0.1)
            ends.append(duration)
        }
        guard duration <= 15 else { throw Failure(text: "第一版支持最长 15 秒的 GIF，请先裁短再选择。") }
        let frameCount = max(1, Int(ceil(duration * 10)))
        let delay = duration / Double(frameCount)
        for side in [466, 320, 240] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.gif.identifier as CFString, frameCount, nil) else { continue }
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            var sourceIndex = 0
            for frame in 0..<frameCount {
                let time = Double(frame) * delay
                while sourceIndex + 1 < ends.count, ends[sourceIndex] <= time { sourceIndex += 1 }
                try autoreleasepool {
                    guard let image = CGImageSourceCreateImageAtIndex(source, sourceIndex, nil),
                          let resized = square(image, side: side) else {
                        throw Failure(text: "GIF 含有无法读取的画面，请换一个。")
                    }
                    CGImageDestinationAddImage(destination, resized, [kCGImagePropertyGIFDictionary:
                        [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
                }
            }
            if CGImageDestinationFinalize(destination), output.length <= 512 * 1024 {
                return BadgePreparedAsset(data: output as Data, format: 2,
                    detail: "GIF 动图 · \(side) × \(side) · \(frameCount) 帧")
            }
        }
        throw Failure(text: "GIF 压缩后仍超过 512 KB，请选择更短或画面更简单的动图。")
    }
}
