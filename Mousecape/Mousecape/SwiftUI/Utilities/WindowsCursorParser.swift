//
//  WindowsCursorParser.swift
//  Mousecape
//
//  Native Swift parser for Windows .cur and .ani cursor files.
//  Replaces the Python-based curconvert.py for zero external dependencies.
//

import Foundation
import AppKit
import ImageIO

// MARK: - Parser Errors

enum WindowsCursorParserError: LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case unsupportedFormat(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Cursor file not found"
        case .invalidFormat(let message):
            return "Invalid cursor format: \(message)"
        case .unsupportedFormat(let message):
            return "Unsupported format: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode cursor: \(message)"
        }
    }
}

// MARK: - Parser Result

/// Result from parsing a Windows cursor file
struct WindowsCursorParseResult {
    let image: CGImage
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let frameCount: Int
    let frameDuration: Double

    /// Convert to PNG data
    func pngData() -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}

// MARK: - Binary Reader Helper

/// Helper for reading binary data with Little Endian byte order
private struct BinaryReader {
    let data: Data
    var offset: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    var remaining: Int {
        return data.count - offset
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset + 1 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        // Read bytes individually to avoid alignment issues
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        offset += 2
        // Little endian: low byte first
        return b0 | (b1 << 8)
    }

    mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        // Read bytes individually to avoid alignment issues
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        offset += 4
        // Little endian: low byte first
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    mutating func readInt32() throws -> Int32 {
        let unsigned = try readUInt32()
        return Int32(bitPattern: unsigned)
    }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        let bytes = data.subdata(in: offset..<(offset + count))
        offset += count
        return bytes
    }

    mutating func skip(_ count: Int) throws {
        guard offset + count <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        offset += count
    }

    mutating func seek(to position: Int) throws {
        guard position >= 0 && position <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Invalid seek position")
        }
        offset = position
    }

    func peekBytes(_ count: Int) -> Data? {
        guard offset + count <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + count))
    }
}

// MARK: - ICONDIR Entry

private struct IconDirEntry {
    let width: Int      // 0 means 256
    let height: Int     // 0 means 256
    let colorCount: Int
    let reserved: Int
    let hotspotX: Int   // For cursors: hotspot X
    let hotspotY: Int   // For cursors: hotspot Y
    let imageSize: Int
    let imageOffset: Int
}

// MARK: - Main Parser

/// Native Swift parser for Windows cursor files
struct WindowsCursorParser {

    // MARK: - Public API

    /// Parse a cursor file from URL
    static func parse(fileURL: URL) throws -> WindowsCursorParseResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw WindowsCursorParserError.fileNotFound
        }

        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.lowercased()

        switch ext {
        case "cur":
            return try parseCUR(data: data)
        case "ani":
            return try parseANI(data: data)
        default:
            throw WindowsCursorParserError.unsupportedFormat("Unknown extension: \(ext)")
        }
    }

    /// Parse a folder of cursor files
    static func parseFolder(folderURL: URL) throws -> [WindowsCursorParseResult] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else {
            throw WindowsCursorParserError.invalidFormat("Cannot enumerate folder")
        }

        var results: [WindowsCursorParseResult] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cur" || ext == "ani" {
                if let result = try? parse(fileURL: fileURL) {
                    results.append(result)
                }
            }
        }

        return results
    }

    // MARK: - CUR Parsing

    /// Parse a .cur (static cursor) file
    static func parseCUR(data: Data) throws -> WindowsCursorParseResult {
        var reader = BinaryReader(data)

        // Read ICONDIR header
        let reserved = try reader.readUInt16()
        let imageType = try reader.readUInt16()
        let imageCount = try reader.readUInt16()

        guard reserved == 0 else {
            throw WindowsCursorParserError.invalidFormat("Invalid reserved field")
        }

        guard imageType == 2 else {
            throw WindowsCursorParserError.invalidFormat("Not a cursor file (type=\(imageType), expected 2)")
        }

        guard imageCount >= 1 else {
            throw WindowsCursorParserError.invalidFormat("No cursor images in file")
        }

        // Read all ICONDIRENTRY entries
        var entries: [IconDirEntry] = []
        for _ in 0..<imageCount {
            let width = Int(try reader.readUInt8())
            let height = Int(try reader.readUInt8())
            let colorCount = Int(try reader.readUInt8())
            let reserved = Int(try reader.readUInt8())
            let hotspotX = Int(try reader.readUInt16())
            let hotspotY = Int(try reader.readUInt16())
            let imageSize = Int(try reader.readUInt32())
            let imageOffset = Int(try reader.readUInt32())

            entries.append(IconDirEntry(
                width: width == 0 ? 256 : width,
                height: height == 0 ? 256 : height,
                colorCount: colorCount,
                reserved: reserved,
                hotspotX: hotspotX,
                hotspotY: hotspotY,
                imageSize: imageSize,
                imageOffset: imageOffset
            ))
        }

        // Choose the largest image (prefer higher resolution)
        guard let bestEntry = entries.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            throw WindowsCursorParserError.invalidFormat("No valid entries")
        }

        // Read image data
        try reader.seek(to: bestEntry.imageOffset)
        let imageData = try reader.readBytes(bestEntry.imageSize)

        // Decode the image
        let cgImage = try decodeImageData(imageData, width: bestEntry.width, height: bestEntry.height)

        return WindowsCursorParseResult(
            image: cgImage,
            width: cgImage.width,
            height: cgImage.height,
            hotspotX: bestEntry.hotspotX,
            hotspotY: bestEntry.hotspotY,
            frameCount: 1,
            frameDuration: 0.0
        )
    }

    // MARK: - ANI Parsing

    /// Parse a .ani (animated cursor) file
    static func parseANI(data: Data) throws -> WindowsCursorParseResult {
        var reader = BinaryReader(data)

        // Verify RIFF header
        let riffHeader = try reader.readBytes(4)
        guard riffHeader == Data("RIFF".utf8) else {
            throw WindowsCursorParserError.invalidFormat("Not a valid RIFF file")
        }

        let _ = try reader.readUInt32() // file size

        let aconType = try reader.readBytes(4)
        guard aconType == Data("ACON".utf8) else {
            throw WindowsCursorParserError.invalidFormat("Not an animated cursor file")
        }

        // Parse chunks
        var anihData: ANIHeader?
        var rateData: [UInt32]?
        var frames: [FrameData] = []

        while reader.remaining >= 8 {
            let chunkID = try reader.readBytes(4)
            let chunkSize = Int(try reader.readUInt32())

            if chunkID == Data("anih".utf8) {
                anihData = try parseANIHChunk(reader: &reader, size: chunkSize)
            } else if chunkID == Data("rate".utf8) {
                let numFrames = anihData?.numFrames ?? 0
                rateData = try parseRateChunk(reader: &reader, size: chunkSize, numFrames: numFrames)
            } else if chunkID == Data("LIST".utf8) {
                let listType = try reader.readBytes(4)
                if listType == Data("fram".utf8) {
                    frames = try parseFramList(reader: &reader, size: chunkSize - 4)
                } else {
                    try reader.skip(chunkSize - 4)
                }
            } else {
                try reader.skip(chunkSize)
            }

            // Pad to even boundary
            if chunkSize % 2 == 1 && reader.remaining > 0 {
                try reader.skip(1)
            }
        }

        guard !frames.isEmpty else {
            throw WindowsCursorParserError.invalidFormat("No frames found in ANI file")
        }

        // Use default values if anih not found
        let header = anihData ?? ANIHeader(
            headerSize: 36,
            numFrames: UInt32(frames.count),
            numSteps: UInt32(frames.count),
            width: 0,
            height: 0,
            bitCount: 0,
            numPlanes: 0,
            displayRate: 10,
            flags: 0
        )

        // Calculate frame duration (jiffies to seconds, 1 jiffy = 1/60 sec)
        let frameDuration: Double
        if let rates = rateData, !rates.isEmpty {
            let avgRate = Double(rates.reduce(0, +)) / Double(rates.count)
            frameDuration = avgRate / 60.0
        } else {
            frameDuration = Double(header.displayRate) / 60.0
        }

        // Get dimensions from first frame
        guard let firstFrame = frames.first else {
            throw WindowsCursorParserError.invalidFormat("No valid frames")
        }

        let frameWidth = firstFrame.image.width
        let frameHeight = firstFrame.image.height

        // Create sprite sheet (all frames stacked vertically)
        let spriteSheet = try createSpriteSheet(frames: frames, width: frameWidth, height: frameHeight)

        return WindowsCursorParseResult(
            image: spriteSheet,
            width: frameWidth,
            height: frameHeight,
            hotspotX: firstFrame.hotspotX,
            hotspotY: firstFrame.hotspotY,
            frameCount: frames.count,
            frameDuration: frameDuration
        )
    }

    // MARK: - ANI Chunk Parsing

    private struct ANIHeader {
        let headerSize: UInt32
        let numFrames: UInt32
        let numSteps: UInt32
        let width: UInt32
        let height: UInt32
        let bitCount: UInt32
        let numPlanes: UInt32
        let displayRate: UInt32
        let flags: UInt32
    }

    private struct FrameData {
        let image: CGImage
        let hotspotX: Int
        let hotspotY: Int
    }

    private static func parseANIHChunk(reader: inout BinaryReader, size: Int) throws -> ANIHeader {
        guard size >= 36 else {
            try reader.skip(size)
            return ANIHeader(headerSize: 36, numFrames: 1, numSteps: 1, width: 0, height: 0, bitCount: 0, numPlanes: 0, displayRate: 10, flags: 0)
        }

        let headerSize = try reader.readUInt32()
        let numFrames = try reader.readUInt32()
        let numSteps = try reader.readUInt32()
        let width = try reader.readUInt32()
        let height = try reader.readUInt32()
        let bitCount = try reader.readUInt32()
        let numPlanes = try reader.readUInt32()
        let displayRate = try reader.readUInt32()
        let flags = try reader.readUInt32()

        // Skip remaining bytes if any
        if size > 36 {
            try reader.skip(size - 36)
        }

        return ANIHeader(
            headerSize: headerSize,
            numFrames: numFrames,
            numSteps: numSteps,
            width: width,
            height: height,
            bitCount: bitCount,
            numPlanes: numPlanes,
            displayRate: displayRate,
            flags: flags
        )
    }

    private static func parseRateChunk(reader: inout BinaryReader, size: Int, numFrames: UInt32) throws -> [UInt32] {
        var rates: [UInt32] = []
        let count = min(Int(numFrames), size / 4)

        for _ in 0..<count {
            let rate = try reader.readUInt32()
            rates.append(rate)
        }

        // Skip remaining bytes
        let remaining = size - (count * 4)
        if remaining > 0 {
            try reader.skip(remaining)
        }

        return rates
    }

    private static func parseFramList(reader: inout BinaryReader, size: Int) throws -> [FrameData] {
        var frames: [FrameData] = []
        let endOffset = reader.offset + size

        while reader.offset < endOffset - 8 {
            let chunkID = try reader.readBytes(4)
            let chunkSize = Int(try reader.readUInt32())

            if chunkID == Data("icon".utf8) {
                let iconData = try reader.readBytes(chunkSize)
                if let frame = try? parseIconChunk(data: iconData) {
                    frames.append(frame)
                }
            } else {
                try reader.skip(chunkSize)
            }

            // Pad to even boundary
            if chunkSize % 2 == 1 && reader.offset < endOffset {
                try reader.skip(1)
            }
        }

        return frames
    }

    private static func parseIconChunk(data: Data) throws -> FrameData {
        var reader = BinaryReader(data)

        // Read ICONDIR header
        let reserved = try reader.readUInt16()
        let imageType = try reader.readUInt16()
        let imageCount = try reader.readUInt16()

        guard reserved == 0 && imageType >= 1 && imageType <= 2 && imageCount >= 1 else {
            throw WindowsCursorParserError.invalidFormat("Invalid icon chunk")
        }

        // Read first ICONDIRENTRY
        let width = Int(try reader.readUInt8())
        let height = Int(try reader.readUInt8())
        let _ = try reader.readUInt8() // colorCount
        let _ = try reader.readUInt8() // reserved
        let hotspotX = Int(try reader.readUInt16())
        let hotspotY = Int(try reader.readUInt16())
        let imageSize = Int(try reader.readUInt32())
        let imageOffset = Int(try reader.readUInt32())

        let actualWidth = width == 0 ? 256 : width
        let actualHeight = height == 0 ? 256 : height

        guard imageOffset + imageSize <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Invalid image offset in icon chunk")
        }

        let imageData = data.subdata(in: imageOffset..<(imageOffset + imageSize))
        let cgImage = try decodeImageData(imageData, width: actualWidth, height: actualHeight)

        return FrameData(image: cgImage, hotspotX: hotspotX, hotspotY: hotspotY)
    }

    // MARK: - Image Decoding

    /// Decode image data (PNG or BMP/DIB format)
    private static func decodeImageData(_ data: Data, width: Int, height: Int) throws -> CGImage {
        // Check for PNG signature
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        if data.prefix(8) == pngSignature {
            return try decodePNG(data: data)
        }

        // Otherwise it's BMP/DIB format
        return try decodeBMPCursor(data: data, width: width, height: height)
    }

    /// Decode PNG data
    private static func decodePNG(data: Data) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw WindowsCursorParserError.decodingFailed("Failed to decode PNG")
        }
        return cgImage
    }

    /// Decode BMP/DIB cursor image data
    private static func decodeBMPCursor(data: Data, width: Int, height: Int) throws -> CGImage {
        var reader = BinaryReader(data)

        // Read BITMAPINFOHEADER
        let headerSize = try reader.readUInt32()
        let bmpWidth = Int(try reader.readInt32())
        let bmpHeight = Int(try reader.readInt32())  // Doubled for XOR+AND masks
        let _ = try reader.readUInt16() // planes (unused)
        let bitCount = try reader.readUInt16()
        let _ = try reader.readUInt32() // compression (unused)

        // Skip rest of header
        if headerSize > 20 {
            try reader.skip(Int(headerSize) - 20)
        }

        // Actual height is half (top half is XOR, bottom half is AND)
        let actualHeight = abs(bmpHeight) / 2
        let actualWidth = bmpWidth > 0 ? bmpWidth : width

        switch bitCount {
        case 32:
            return try decode32BitBMP(reader: &reader, width: actualWidth, height: actualHeight)
        case 24:
            return try decode24BitBMP(reader: &reader, width: actualWidth, height: actualHeight)
        default:
            // For other bit depths, try using ImageIO with a BMP header wrapper
            return try decodeBMPWithHeader(data: data, width: width, height: height)
        }
    }

    /// Decode 32-bit BGRA BMP
    private static func decode32BitBMP(reader: inout BinaryReader, width: Int, height: Int) throws -> CGImage {
        var pixelData = Data(count: width * height * 4)

        // Read rows bottom-to-top (BMP is stored upside down)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let b = try reader.readUInt8()
                let g = try reader.readUInt8()
                let r = try reader.readUInt8()
                let a = try reader.readUInt8()

                let offset = (targetY * width + x) * 4
                pixelData[offset] = r
                pixelData[offset + 1] = g
                pixelData[offset + 2] = b
                pixelData[offset + 3] = a
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 24-bit BGR BMP with separate AND mask
    private static func decode24BitBMP(reader: inout BinaryReader, width: Int, height: Int) throws -> CGImage {
        let rowSize = ((width * 3 + 3) / 4) * 4  // Padded to 4 bytes
        let padding = rowSize - width * 3

        var pixelData = Data(count: width * height * 4)

        // Read color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let b = try reader.readUInt8()
                let g = try reader.readUInt8()
                let r = try reader.readUInt8()

                let offset = (targetY * width + x) * 4
                pixelData[offset] = r
                pixelData[offset + 1] = g
                pixelData[offset + 2] = b
                pixelData[offset + 3] = 255  // Will be updated by AND mask
            }

            // Skip padding
            if padding > 0 {
                try reader.skip(padding)
            }
        }

        // Read AND mask (1-bit transparency)
        let andRowSize = ((width + 31) / 32) * 4

        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<(andRowSize) {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0  // Set alpha to 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Fallback: wrap DIB with BMP header and use ImageIO
    private static func decodeBMPWithHeader(data: Data, width: Int, height: Int) throws -> CGImage {
        // Create BMP file header
        var bmpData = Data()

        // BM signature
        bmpData.append(contentsOf: [0x42, 0x4D])

        // File size
        let fileSize = UInt32(14 + data.count)
        bmpData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })

        // Reserved
        bmpData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Offset to pixel data (14 + header size)
        let headerSize = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let offset = UInt32(14) + headerSize
        bmpData.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })

        // Append DIB data
        bmpData.append(data)

        // Try to decode with ImageIO
        guard let imageSource = CGImageSourceCreateWithData(bmpData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            // Create a placeholder image if decoding fails
            return try createPlaceholderImage(width: width, height: height)
        }

        return cgImage
    }

    /// Create CGImage from RGBA pixel data
    private static func createCGImage(from data: Data, width: Int, height: Int) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: data as CFData) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create data provider")
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create CGImage")
        }

        return cgImage
    }

    /// Create a placeholder image for unsupported formats
    private static func createPlaceholderImage(width: Int, height: Int) throws -> CGImage {
        var pixelData = Data(count: width * height * 4)

        // Fill with semi-transparent magenta (indicates unsupported format)
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            pixelData[i] = 255      // R
            pixelData[i + 1] = 0    // G
            pixelData[i + 2] = 255  // B
            pixelData[i + 3] = 128  // A
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Create sprite sheet from multiple frames
    private static func createSpriteSheet(frames: [FrameData], width: Int, height: Int) throws -> CGImage {
        let totalHeight = height * frames.count

        // Create a graphics context for the sprite sheet
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create graphics context")
        }

        // Draw each frame
        for (index, frame) in frames.enumerated() {
            let y = totalHeight - (index + 1) * height  // CGContext origin is bottom-left

            // Scale frame if needed
            var frameImage = frame.image
            if frame.image.width != width || frame.image.height != height {
                if let scaled = scaleImage(frame.image, to: CGSize(width: width, height: height)) {
                    frameImage = scaled
                }
            }

            context.draw(frameImage, in: CGRect(x: 0, y: y, width: width, height: height))
        }

        guard let spriteSheet = context.makeImage() else {
            throw WindowsCursorParserError.decodingFailed("Failed to create sprite sheet")
        }

        return spriteSheet
    }

    /// Scale an image to a new size
    private static func scaleImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return context.makeImage()
    }
}
