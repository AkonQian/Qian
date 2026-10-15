import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MOTO_GPS

final class BadgeFeatureTests: XCTestCase {
    private func fixture(type: UTType, delays: [Double] = []) throws -> Data {
        let count = max(1, delays.count)
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output as CFMutableData, type.identifier as CFString, count, nil))
        for index in 0..<count {
            let context = try XCTUnwrap(CGContext(data: nil, width: 640, height: 320,
                bitsPerComponent: 8, bytesPerRow: 640 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(index.isMultiple(of: 2)
                ? CGColor(red: 1, green: 0, blue: 0, alpha: 1)
                : CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 320))
            let image = try XCTUnwrap(context.makeImage())
            let properties: CFDictionary? = delays.isEmpty ? nil : [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delays[index]]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, image, properties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func testStillImageIsConvertedToBoundedSquareJPEG() throws {
        let asset = try BadgeAssetEncoder.prepare(fixture(type: .png))
        XCTAssertEqual(asset.format, 1)
        XCTAssertLessThanOrEqual(asset.data.count, 512 * 1024)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(asset.data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source).map { $0 as String }, UTType.jpeg.identifier)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 466)
        XCTAssertEqual(image.height, 466)
    }

    func testGIFRemainsAnimatedAndPreservesDuration() throws {
        let asset = try BadgeAssetEncoder.prepare(fixture(type: .gif, delays: [0.5, 0.5]))
        XCTAssertEqual(asset.format, 2)
        XCTAssertLessThanOrEqual(asset.data.count, 512 * 1024)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(asset.data as CFData, nil))
        let count = CGImageSourceGetCount(source)
        XCTAssertGreaterThan(count, 1)
        XCTAssertLessThanOrEqual(count, 10)
        var duration = 0.0
        for index in 0..<count {
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, index, nil))
            XCTAssertEqual(image.width, image.height)
            XCTAssertLessThanOrEqual(image.width, 466)
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as NSDictionary?)
            let gif = try XCTUnwrap(properties[kCGImagePropertyGIFDictionary] as? NSDictionary)
            duration += try XCTUnwrap(gif[kCGImagePropertyGIFDelayTime] as? NSNumber).doubleValue
        }
        XCTAssertEqual(duration, 1, accuracy: 0.11)
    }

    func testInvalidInputAndLongAnimationAreRejected() throws {
        XCTAssertThrowsError(try BadgeAssetEncoder.prepare(Data("not an image".utf8)))
        XCTAssertThrowsError(try BadgeAssetEncoder.prepare(Data(repeating: 0, count: 20 * 1024 * 1024 + 1)))
        XCTAssertThrowsError(try BadgeAssetEncoder.prepare(fixture(type: .gif, delays: [8, 8])))
    }

    func testBeginPayloadMatchesIndependentCRCVector() {
        let payload = MotoBadgeCodec.beginPayload(Data("123456789".utf8))
        XCTAssertEqual(Array(payload), [9, 0, 0, 0, 0x26, 0x39, 0xf4, 0xcb])
    }

    func testReplyValidationAndCatalogDecoding() throws {
        let reply = Data([0x42, 0x47, 1, 0x83, 0x78, 0x56, 0x34, 0x12,
                          2, 0, 5, 0, 0xa6, 0, 0, 0, 2, 1, 0, 2, 0])
        let decoded = try XCTUnwrap(MotoBadgeCodec.decodeReply(reply))
        XCTAssertEqual(decoded.requestID, 0x12345678)
        XCTAssertEqual(decoded.operation, 3)
        XCTAssertEqual(decoded.slot, 2)
        XCTAssertEqual(decoded.offset, 166)
        XCTAssertEqual(decoded.selected, 2)
        XCTAssertEqual(decoded.formats.map(\.uint8Value), [1, 0, 2, 0])
        XCTAssertNil(MotoBadgeCodec.decodeReply(Data(reply.dropLast())))
        var bad = reply; bad[2] = 2
        XCTAssertNil(MotoBadgeCodec.decodeReply(bad))
        bad = reply; bad[16] = 4
        XCTAssertNil(MotoBadgeCodec.decodeReply(bad))
        bad = reply; bad[17] = 3
        XCTAssertNil(MotoBadgeCodec.decodeReply(bad))
    }
}
