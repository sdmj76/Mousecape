//
//  WindowsCursorConverter.swift
//  Mousecape
//
//  Converts Windows .cur/.ani cursor files using bundled Python + Pillow
//

#if ENABLE_WINDOWS_IMPORT

import Foundation
import AppKit

// MARK: - Conversion Result

/// Result from converting a Windows cursor file
struct WindowsCursorResult {
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let frameCount: Int
    let frameDuration: Double
    let imageData: Data  // PNG sprite sheet (for animated: frames stacked vertically)
    let filename: String // Original filename without extension
}

// MARK: - Conversion Error

enum WindowsCursorError: LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case conversionFailed(String)
    case invalidOutput
    case imageDecodeFailed

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python environment not found in app bundle"
        case .scriptNotFound:
            return "Cursor conversion script not found"
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        case .invalidOutput:
            return "Invalid output from conversion script"
        case .imageDecodeFailed:
            return "Failed to decode image data"
        }
    }
}

// MARK: - Converter

/// Converts Windows cursor files (.cur, .ani) to Mousecape format
final class WindowsCursorConverter: @unchecked Sendable {

    /// Shared instance
    static let shared = WindowsCursorConverter()

    /// Nonisolated accessor for use from any context
    nonisolated static var instance: WindowsCursorConverter { shared }

    private init() {}

    // MARK: - Public API

    /// Convert a single cursor file
    /// - Parameter fileURL: URL to .cur or .ani file
    /// - Returns: Conversion result with image data
    func convert(fileURL: URL) throws -> WindowsCursorResult {
        let jsonOutput = try runConversionScript(arguments: [fileURL.path])
        return try parseResult(jsonOutput, defaultFilename: fileURL.deletingPathExtension().lastPathComponent)
    }

    /// Convert all cursor files in a folder
    /// - Parameter folderURL: URL to folder containing .cur/.ani files
    /// - Returns: Array of conversion results
    func convertFolder(folderURL: URL) throws -> [WindowsCursorResult] {
        let jsonOutput = try runConversionScript(arguments: ["--folder", folderURL.path])
        return try parseFolderResult(jsonOutput)
    }

    // MARK: - Async Public API

    /// Convert all cursor files in a folder asynchronously
    /// - Parameter folderURL: URL to folder containing .cur/.ani files
    /// - Returns: Array of conversion results
    func convertFolderAsync(folderURL: URL) async throws -> [WindowsCursorResult] {
        let jsonOutput = try await runConversionScriptAsync(arguments: ["--folder", folderURL.path])
        return try parseFolderResult(jsonOutput)
    }

    // MARK: - Private Methods

    /// Find the bundled Python script and environment
    private func findBundledResources() throws -> (scriptPath: String, wrapperPath: String) {
        guard let resourcesPath = Bundle.main.resourcePath else {
            throw WindowsCursorError.scriptNotFound
        }

        let wrapperPath = (resourcesPath as NSString).appendingPathComponent("run_curconvert.sh")
        let scriptPath = (resourcesPath as NSString).appendingPathComponent("curconvert.py")

        guard FileManager.default.fileExists(atPath: wrapperPath) else {
            throw WindowsCursorError.pythonNotFound
        }

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw WindowsCursorError.scriptNotFound
        }

        return (scriptPath, wrapperPath)
    }

    /// Run the conversion script
    private func runConversionScript(arguments: [String]) throws -> Data {
        let resources = try findBundledResources()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [resources.wrapperPath] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WindowsCursorError.conversionFailed(errorMessage)
        }

        return outputData
    }

    /// Run the conversion script asynchronously (doesn't block main thread)
    private func runConversionScriptAsync(arguments: [String]) async throws -> Data {
        let resources = try findBundledResources()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    print("[WindowsCursorConverter] Starting process with arguments: \(arguments)")

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/bash")
                    process.arguments = [resources.wrapperPath] + arguments

                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    // Use thread-safe container
                    class DataContainer: @unchecked Sendable {
                        var outputData = Data()
                        var errorData = Data()
                        private let lock = NSLock()

                        func appendOutput(_ data: Data) {
                            lock.lock()
                            defer { lock.unlock() }
                            outputData.append(data)
                        }

                        func appendError(_ data: Data) {
                            lock.lock()
                            defer { lock.unlock() }
                            errorData.append(data)
                        }
                    }

                    let container = DataContainer()

                    // Set up async data reading
                    let outputHandle = outputPipe.fileHandleForReading
                    let errorHandle = errorPipe.fileHandleForReading

                    outputHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            container.appendOutput(data)
                        }
                    }

                    errorHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            container.appendError(data)
                        }
                    }

                    process.terminationHandler = { proc in
                        // Clean up handlers
                        outputHandle.readabilityHandler = nil
                        errorHandle.readabilityHandler = nil

                        // Read any remaining data
                        container.appendOutput(outputHandle.readDataToEndOfFile())
                        container.appendError(errorHandle.readDataToEndOfFile())

                        print("[WindowsCursorConverter] Process finished with status: \(proc.terminationStatus)")
                        print("[WindowsCursorConverter] Output size: \(container.outputData.count) bytes")

                        if proc.terminationStatus != 0 {
                            let errorMessage = String(data: container.errorData, encoding: .utf8) ?? "Unknown error"
                            print("[WindowsCursorConverter] Error: \(errorMessage)")
                            continuation.resume(throwing: WindowsCursorError.conversionFailed(errorMessage))
                        } else {
                            continuation.resume(returning: container.outputData)
                        }
                    }

                    try process.run()
                    print("[WindowsCursorConverter] Process started successfully")

                } catch {
                    print("[WindowsCursorConverter] Failed to start process: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Parse single file result
    private func parseResult(_ jsonData: Data, defaultFilename: String) throws -> WindowsCursorResult {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw WindowsCursorError.invalidOutput
        }

        guard json["success"] as? Bool == true else {
            let error = json["error"] as? String ?? "Unknown error"
            throw WindowsCursorError.conversionFailed(error)
        }

        return try parseResultDict(json, defaultFilename: defaultFilename)
    }

    /// Parse folder result
    private func parseFolderResult(_ jsonData: Data) throws -> [WindowsCursorResult] {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw WindowsCursorError.invalidOutput
        }

        guard json["success"] as? Bool == true else {
            let error = json["error"] as? String ?? "Unknown error"
            throw WindowsCursorError.conversionFailed(error)
        }

        guard let cursors = json["cursors"] as? [[String: Any]] else {
            throw WindowsCursorError.invalidOutput
        }

        var results: [WindowsCursorResult] = []

        for cursorDict in cursors {
            if cursorDict["success"] as? Bool == true {
                let filename = cursorDict["filename"] as? String ?? "unknown"
                if let result = try? parseResultDict(cursorDict, defaultFilename: filename) {
                    results.append(result)
                }
            }
        }

        return results
    }

    /// Parse a single result dictionary
    private func parseResultDict(_ dict: [String: Any], defaultFilename: String) throws -> WindowsCursorResult {
        guard let width = dict["width"] as? Int,
              let height = dict["height"] as? Int,
              let hotspotX = dict["hotspotX"] as? Int,
              let hotspotY = dict["hotspotY"] as? Int,
              let frameCount = dict["frameCount"] as? Int,
              let imageDataBase64 = dict["imageData"] as? String else {
            throw WindowsCursorError.invalidOutput
        }

        let frameDuration = dict["frameDuration"] as? Double ?? 0.0
        let filename = dict["filename"] as? String ?? defaultFilename

        guard let imageData = Data(base64Encoded: imageDataBase64) else {
            throw WindowsCursorError.imageDecodeFailed
        }

        return WindowsCursorResult(
            width: width,
            height: height,
            hotspotX: hotspotX,
            hotspotY: hotspotY,
            frameCount: frameCount,
            frameDuration: frameDuration,
            imageData: imageData,
            filename: filename
        )
    }
}

// MARK: - NSBitmapImageRep Extension

extension WindowsCursorResult {

    /// Create NSBitmapImageRep from the result
    /// For animated cursors, returns a sprite sheet with all frames stacked vertically
    func createBitmapImageRep() -> NSBitmapImageRep? {
        guard let image = NSImage(data: imageData) else { return nil }

        // Get the bitmap representation
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSBitmapImageRep(cgImage: cgImage)
    }

    /// Create MCCursor from the result
    func createMCCursor(identifier: String) -> MCCursor? {
        guard let bitmap = createBitmapImageRep() else { return nil }

        let cursor = MCCursor()
        cursor.identifier = identifier
        cursor.frameCount = UInt(frameCount)
        cursor.frameDuration = frameDuration
        cursor.size = NSSize(width: CGFloat(width), height: CGFloat(height))
        cursor.hotSpot = NSPoint(x: CGFloat(hotspotX), y: CGFloat(hotspotY))

        // Set representation for 2x scale (standard HiDPI)
        cursor.setRepresentation(bitmap, for: MCCursorScale(rawValue: 200)!)

        return cursor
    }
}

#endif
