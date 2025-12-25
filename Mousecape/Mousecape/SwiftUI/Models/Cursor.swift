//
//  Cursor.swift
//  Mousecape
//
//  Swift wrapper for MCCursor
//

import Foundation
import AppKit

/// Swift wrapper around MCCursor for SwiftUI usage
@Observable
final class Cursor: Identifiable, Hashable {
    let id: UUID
    private let objcCursor: MCCursor

    // MARK: - Properties (bridged from ObjC)

    var identifier: String {
        get { objcCursor.identifier ?? "" }
        set { objcCursor.identifier = newValue }
    }

    var name: String {
        // First try ObjC cursor name
        if let objcName = objcCursor.name, !objcName.isEmpty {
            return objcName
        }
        // Then try to extract from identifier
        if !identifier.isEmpty, let lastName = identifier.components(separatedBy: ".").last, !lastName.isEmpty {
            return lastName
        }
        return "Unknown"
    }

    var displayName: String {
        // First check if we have a known cursor type - use its display name
        if let type = CursorType(rawValue: identifier) {
            return type.displayName
        }
        // Clean up the name for display
        let baseName = name
        // Convert camelCase to Title Case with spaces
        var result = ""
        for char in baseName {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.isEmpty ? "Cursor" : result
    }

    var frameDuration: CGFloat {
        get { objcCursor.frameDuration }
        set { objcCursor.frameDuration = newValue }
    }

    var frameCount: Int {
        get { Int(objcCursor.frameCount) }
        set { objcCursor.frameCount = UInt(newValue) }
    }

    var size: NSSize {
        get { objcCursor.size }
        set { objcCursor.size = newValue }
    }

    var hotSpot: NSPoint {
        get { objcCursor.hotSpot }
        set { objcCursor.hotSpot = newValue }
    }

    var isAnimated: Bool {
        frameCount > 1
    }

    // MARK: - Image Access

    /// Get the full image with all representations
    var image: NSImage? {
        objcCursor.imageWithAllReps()
    }

    /// Get representation at specific scale
    func representation(for scale: CursorScale) -> NSImageRep? {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return nil
        }
        return objcCursor.representation(for: mcScale)
    }

    /// Set representation at specific scale
    func setRepresentation(_ imageRep: NSImageRep, for scale: CursorScale) {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return
        }
        objcCursor.setRepresentation(imageRep, for: mcScale)
    }

    /// Remove representation at specific scale
    func removeRepresentation(for scale: CursorScale) {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return
        }
        objcCursor.removeRepresentation(for: mcScale)
    }

    /// Check if a representation exists for scale
    func hasRepresentation(for scale: CursorScale) -> Bool {
        representation(for: scale) != nil
    }

    /// Check if cursor has any actual image data
    var hasAnyRepresentation: Bool {
        for scale in CursorScale.allCases {
            if hasRepresentation(for: scale) {
                return true
            }
        }
        return false
    }

    // MARK: - Cursor Type

    var cursorType: CursorType? {
        CursorType(rawValue: identifier)
    }

    // MARK: - Initialization

    init(objcCursor: MCCursor) {
        self.id = UUID()
        self.objcCursor = objcCursor
    }

    /// Create a new empty cursor with identifier
    convenience init(identifier: String) {
        let cursor = MCCursor()
        cursor.identifier = identifier
        cursor.frameCount = 1
        cursor.frameDuration = 1.0  // Default 1 fps
        cursor.size = NSSize(width: 32, height: 32)  // Default size
        cursor.hotSpot = NSPoint(x: 0, y: 0)
        self.init(objcCursor: cursor)
    }

    // MARK: - ObjC Bridge

    /// Get the underlying ObjC cursor object
    var underlyingCursor: MCCursor {
        objcCursor
    }

    // MARK: - Hashable & Equatable

    static func == (lhs: Cursor, rhs: Cursor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Cursor Preview Helper

extension Cursor {
    /// Get a preview image at the specified size
    func previewImage(size: CGFloat = 48) -> NSImage? {
        guard let image = self.image else { return nil }

        let previewImage = NSImage(size: NSSize(width: size, height: size))
        previewImage.lockFocus()

        // Draw first frame only
        let drawRect = NSRect(x: 0, y: 0, width: size, height: size)
        let frameHeight = image.size.height / CGFloat(max(1, frameCount))
        let sourceRect = NSRect(x: 0, y: image.size.height - frameHeight, width: image.size.width, height: frameHeight)

        image.draw(in: drawRect, from: sourceRect, operation: .copy, fraction: 1.0)

        previewImage.unlockFocus()
        return previewImage
    }
}
