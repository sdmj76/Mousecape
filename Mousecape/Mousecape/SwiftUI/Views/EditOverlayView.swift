//
//  EditOverlayView.swift
//  Mousecape
//
//  Edit overlay view that covers the main interface
//  Slides in from the right with animation
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Edit Detail View (for right panel only, with cursor list)

struct EditDetailView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            // Left: Cursor list
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Right: Detail content
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 300)
        }
        .onAppear {
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
                .id(cursor.id)  // Force view recreation when cursor changes
        } else {
            ContentUnavailableView(
                "Select a Cursor",
                systemImage: "cursorarrow.click",
                description: Text("Choose a cursor from the list to edit")
            )
        }
    }
}

// MARK: - Edit Overlay View (legacy, full screen)

struct EditOverlayView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Left sidebar: Cursor list (same style as HomeView/SettingsView)
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            // Right side: Content area
            detailContent
        }
        .onAppear {
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
                .id(cursor.id)  // Force view recreation when cursor changes
        } else {
            ContentUnavailableView(
                "Select a Cursor",
                systemImage: "cursorarrow.click",
                description: Text("Choose a cursor from the list to edit")
            )
        }
    }
}

// MARK: - Cape Info View (Metadata Editor)

struct CapeInfoView: View {
    @Bindable var cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cape metadata form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cape Information")
                        .font(.headline)

                    LabeledContent("Name") {
                        TextField("Cape Name", text: Binding(
                            get: { cape.name },
                            set: { newValue in
                                let oldValue = cape.name
                                guard newValue != oldValue else { return }
                                cape.name = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.name = oldValue },
                                    redo: { [weak cape] in cape?.name = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    }

                    LabeledContent("Author") {
                        TextField("Author", text: Binding(
                            get: { cape.author },
                            set: { newValue in
                                let oldValue = cape.author
                                guard newValue != oldValue else { return }
                                cape.author = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.author = oldValue },
                                    redo: { [weak cape] in cape?.author = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    }

                    LabeledContent("Version") {
                        TextField("Version", value: Binding(
                            get: { cape.version },
                            set: { newValue in
                                let oldValue = cape.version
                                guard newValue != oldValue else { return }
                                cape.version = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.version = oldValue },
                                    redo: { [weak cape] in cape?.version = newValue }
                                )
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    }

                    LabeledContent("Identifier") {
                        TextField("Identifier", text: Binding(
                            get: { cape.identifier },
                            set: { newValue in
                                let oldValue = cape.identifier
                                guard newValue != oldValue else { return }
                                cape.identifier = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.identifier = oldValue },
                                    redo: { [weak cape] in cape?.identifier = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    LabeledContent("Cursors") {
                        Text("\(cape.cursorCount)")
                            .foregroundStyle(.secondary)
                    }

                    if let url = cape.fileURL {
                        LabeledContent("File") {
                            Text(url.lastPathComponent)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                // Cursor summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cursors (\(cape.cursorCount))")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                        ForEach(cape.cursors) { cursor in
                            VStack(spacing: 4) {
                                if let image = cursor.previewImage(size: 48) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: cursor.cursorType?.previewSymbol ?? "cursorarrow")
                                        .font(.title)
                                        .frame(width: 48, height: 48)
                                }
                                Text(cursor.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

// MARK: - Add Cursor Sheet

struct AddCursorSheet: View {
    let cape: CursorLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedType: CursorType?

    // Filter out cursor types that already exist in the cape
    private var availableTypes: [CursorType] {
        let existingIdentifiers = Set(cape.cursors.map { $0.identifier })
        return CursorType.allCases.filter { !existingIdentifiers.contains($0.rawValue) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Cursor")
                .font(.headline)

            cursorTypeList

            buttonBar
        }
        .padding()
        .frame(width: 350, height: 420)
        .onAppear {
            selectedType = availableTypes.first
        }
    }

    @ViewBuilder
    private var cursorTypeList: some View {
        if availableTypes.isEmpty {
            ContentUnavailableView(
                "All Cursor Types Added",
                systemImage: "checkmark.circle",
                description: Text("This cape already contains all standard cursor types.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableTypes) { type in
                        CursorTypeRow(
                            type: type,
                            isSelected: selectedType == type,
                            onSelect: { selectedType = type }
                        )
                    }
                }
                .padding(8)
            }
            .frame(height: 300)
            .glassEffect(.regular.tint(.clear), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Add") {
                addSelectedCursor()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedType == nil || availableTypes.isEmpty)
        }
    }

    private func addSelectedCursor() {
        guard let type = selectedType else { return }

        // Create and add cursor directly via AppState
        let newCursor = Cursor(identifier: type.rawValue)
        cape.addCursor(newCursor)
        appState.markAsChanged()
        appState.cursorListRefreshTrigger += 1
        appState.editingSelectedCursor = newCursor

        // Dismiss sheet
        dismiss()
    }
}

// MARK: - Cursor Type Row

private struct CursorTypeRow: View {
    let type: CursorType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: type.previewSymbol)
                .frame(width: 24)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(type.displayName)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Cursor List View (for Edit)

struct CursorListView: View {
    let cape: CursorLibrary
    @Binding var selection: Cursor?
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(cape.cursors, id: \.id, selection: $selection) { cursor in
            CursorListRow(cursor: cursor, currentIdentifier: cursor.identifier)
                .tag(cursor)
                .contextMenu {
                    Button("Duplicate") {
                        duplicateCursor()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        appState.showDeleteCursorConfirmation = true
                    }
                }
        }
        .listStyle(.sidebar)
        .id(appState.cursorListRefreshTrigger)  // Force list refresh when trigger changes
    }

    private func duplicateCursor() {
        guard let cursor = selection else { return }
        // Create a copy with a modified identifier
        let newCursor = Cursor(identifier: cursor.identifier + ".copy")
        newCursor.frameDuration = cursor.frameDuration
        newCursor.frameCount = cursor.frameCount
        newCursor.size = cursor.size
        newCursor.hotSpot = cursor.hotSpot

        // Copy representations
        for scale in CursorScale.allCases {
            if let rep = cursor.representation(for: scale) {
                newCursor.setRepresentation(rep, for: scale)
            }
        }

        cape.addCursor(newCursor)
        selection = newCursor
        appState.markAsChanged()
    }
}

// MARK: - Cursor List Row

struct CursorListRow: View {
    let cursor: Cursor
    /// Pass the identifier to force refresh when type changes
    var currentIdentifier: String?

    private var displayName: String {
        let identifier = currentIdentifier ?? cursor.identifier
        if let type = CursorType(rawValue: identifier) {
            return type.displayName
        }
        // Fallback: extract name from identifier
        let name = identifier.components(separatedBy: ".").last ?? "Cursor"
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.isEmpty ? "Cursor" : result
    }

    var body: some View {
        HStack {
            // Preview thumbnail
            if let image = cursor.previewImage(size: 32) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                let identifier = currentIdentifier ?? cursor.identifier
                Image(systemName: CursorType(rawValue: identifier)?.previewSymbol ?? "cursorarrow")
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                if cursor.isAnimated {
                    Text("\(cursor.frameCount) frames")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cursor Detail View

struct CursorDetailView: View {
    @Bindable var cursor: Cursor
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @State private var sizeWidth: Double = 0
    @State private var sizeHeight: Double = 0
    @State private var hotspotX: Double = 0
    @State private var hotspotY: Double = 0
    @State private var frameCount: Int = 1
    @State private var fps: Double = 1  // Frames per second
    @State private var isLoadingValues = true  // Prevent onChange during load
    @State private var selectedType: CursorType = .arrow
    @State private var previewRefreshTrigger: Int = 0  // Force preview refresh
    @State private var availableTypes: [CursorType] = CursorType.allCases

    // Calculate available cursor types (current type + types not used by other cursors)
    private func calculateAvailableTypes() -> [CursorType] {
        let otherCursorIdentifiers = Set(cape.cursors
            .filter { $0.id != cursor.id }
            .map { $0.identifier })
        return CursorType.allCases.filter { type in
            !otherCursorIdentifiers.contains(type.rawValue)
        }
    }

    // Calculate frame duration from FPS
    private var frameDuration: Double {
        fps > 0 ? 1.0 / fps : 0
    }

    // Picker types - ensure selectedType is always included to avoid "invalid selection" warning
    private var pickerTypes: [CursorType] {
        if availableTypes.contains(selectedType) {
            return availableTypes
        } else {
            // Add current selection to the list if not present
            return [selectedType] + availableTypes
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Combined preview + drop zone
                CursorPreviewDropZone(
                    cursor: cursor,
                    refreshTrigger: previewRefreshTrigger
                )

                // Properties panel
                VStack(alignment: .leading, spacing: 16) {
                    // Type section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.headline)

                        Picker("", selection: $selectedType) {
                            ForEach(pickerTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .leading)
                        .id(previewRefreshTrigger)  // Force picker refresh
                        .onChange(of: selectedType) { oldValue, newValue in
                            guard !isLoadingValues else { return }
                            guard newValue != oldValue else { return }
                            let oldIdentifier = cursor.identifier
                            let newIdentifier = newValue.rawValue
                            cursor.identifier = newIdentifier
                            appState.cursorListRefreshTrigger += 1
                            appState.registerUndo(
                                undo: { [weak cursor] in
                                    cursor?.identifier = oldIdentifier
                                    if let type = CursorType(rawValue: oldIdentifier) {
                                        self.selectedType = type
                                    }
                                    self.appState.cursorListRefreshTrigger += 1
                                },
                                redo: { [weak cursor] in
                                    cursor?.identifier = newIdentifier
                                    self.selectedType = newValue
                                    self.appState.cursorListRefreshTrigger += 1
                                }
                            )
                        }

                        Text(selectedType.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Size section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Size")
                            .font(.headline)

                        HStack(spacing: 16) {
                            HStack {
                                Text("W:")
                                TextField("Width", value: $sizeWidth, format: .number.precision(.fractionLength(0)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .onChange(of: sizeWidth) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        let actualNew = max(1, newValue)
                                        cursor.size = NSSize(width: actualNew, height: cursor.size.height)
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.size = NSSize(width: capturedOld, height: cursor?.size.height ?? 0)
                                                self.sizeWidth = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.size = NSSize(width: actualNew, height: cursor?.size.height ?? 0)
                                                self.sizeWidth = actualNew
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                            HStack {
                                Text("H:")
                                TextField("Height", value: $sizeHeight, format: .number.precision(.fractionLength(0)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .onChange(of: sizeHeight) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        let actualNew = max(1, newValue)
                                        cursor.size = NSSize(width: cursor.size.width, height: actualNew)
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.size = NSSize(width: cursor?.size.width ?? 0, height: capturedOld)
                                                self.sizeHeight = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.size = NSSize(width: cursor?.size.width ?? 0, height: actualNew)
                                                self.sizeHeight = actualNew
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                        }
                    }

                    Divider()

                    // Hotspot section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hotspot")
                            .font(.headline)

                        HStack(spacing: 16) {
                            HStack {
                                Text("X:")
                                TextField("X", value: $hotspotX, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .onChange(of: hotspotX) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        cursor.hotSpot = NSPoint(x: CGFloat(newValue), y: cursor.hotSpot.y)
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: CGFloat(capturedOld), y: cursor?.hotSpot.y ?? 0)
                                                self.hotspotX = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: CGFloat(newValue), y: cursor?.hotSpot.y ?? 0)
                                                self.hotspotX = newValue
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                            HStack {
                                Text("Y:")
                                TextField("Y", value: $hotspotY, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .onChange(of: hotspotY) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(newValue))
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(capturedOld))
                                                self.hotspotY = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(newValue))
                                                self.hotspotY = newValue
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                        }

                    }

                    Divider()

                    // Animation section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Animation")
                            .font(.headline)

                        HStack {
                            Text("Frames:")
                            TextField("Frames", value: $frameCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: frameCount) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(1, newValue)
                                    cursor.frameCount = actualNew
                                    previewRefreshTrigger += 1
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.frameCount = capturedOld
                                            self.frameCount = capturedOld
                                            self.previewRefreshTrigger += 1
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameCount = actualNew
                                            self.frameCount = actualNew
                                            self.previewRefreshTrigger += 1
                                        }
                                    )
                                }
                        }

                        HStack {
                            Text("FPS:")
                            TextField("FPS", value: $fps, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: fps) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(0.1, newValue)
                                    let newDuration = 1.0 / actualNew
                                    cursor.frameDuration = CGFloat(newDuration)
                                    previewRefreshTrigger += 1
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            let oldDuration = capturedOld > 0 ? 1.0 / capturedOld : 0
                                            cursor?.frameDuration = CGFloat(oldDuration)
                                            self.fps = capturedOld
                                            self.previewRefreshTrigger += 1
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameDuration = CGFloat(newDuration)
                                            self.fps = actualNew
                                            self.previewRefreshTrigger += 1
                                        }
                                    )
                                }
                            Text("frames/sec")
                                .foregroundStyle(.secondary)
                        }

                        if cursor.isAnimated {
                            Text("Duration: \(String(format: "%.3f", frameDuration))s per frame, \(String(format: "%.2f", Double(frameCount) * frameDuration))s total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .onAppear {
            loadCursorValues()
        }
        .onChange(of: cursor.id) { _, _ in
            loadCursorValues()
        }
        .onChange(of: appState.cursorListRefreshTrigger) { _, _ in
            // Refresh preview and reload values when image is imported
            previewRefreshTrigger += 1
            loadCursorValues()
        }
    }

    private func loadCursorValues() {
        isLoadingValues = true
        sizeWidth = Double(cursor.size.width)
        sizeHeight = Double(cursor.size.height)
        hotspotX = Double(cursor.hotSpot.x)
        hotspotY = Double(cursor.hotSpot.y)
        frameCount = cursor.frameCount
        // Calculate FPS from frame duration
        let duration = Double(cursor.frameDuration)
        fps = duration > 0 ? 1.0 / duration : 1.0
        // Refresh available types
        availableTypes = calculateAvailableTypes()
        // Load cursor type
        if let type = CursorType(rawValue: cursor.identifier) {
            selectedType = type
        } else if let firstAvailable = availableTypes.first {
            selectedType = firstAvailable
        }
        // Delay resetting the flag to ensure onChange doesn't fire during load
        DispatchQueue.main.async {
            isLoadingValues = false
        }
    }
}

// MARK: - Cursor Preview Drop Zone (Combined preview + image drop)

struct CursorPreviewDropZone: View {
    @Bindable var cursor: Cursor
    var refreshTrigger: Int = 0
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var showFilePicker = false
    @State private var localRefreshTrigger = 0

    private let targetScale: CursorScale = .scale200  // Always use 2x HiDPI

    /// Check if cursor has any valid image (with non-zero size)
    private var hasImage: Bool {
        guard let image = cursor.image else { return false }
        return image.size.width > 0 && image.size.height > 0
    }

    var body: some View {
        ZStack {
            if hasImage {
                // Show cursor preview with hotspot
                AnimatingCursorView(
                    cursor: cursor,
                    showHotspot: true,
                    refreshTrigger: refreshTrigger + localRefreshTrigger,
                    scale: 1
                )
            } else {
                // Empty state - prompt to add image
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Drag image or click to select")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Recommended: 64×64 px (HiDPI 2x)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Drag overlay indicator
            if isTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            showFilePicker = true
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleURLDrop(urls)
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.png, .jpeg, .tiff, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .help(hasImage ? "Click or drag to replace image" : "Click or drag to add image")
    }

    private func handleURLDrop(_ urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }
        return loadImage(from: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                _ = loadImage(from: url)
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    private func loadImage(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource: \(url)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image from: \(url)")
            return false
        }

        // Convert to bitmap representation
        guard let bitmapRep = createBitmapRep(from: image) else {
            print("Failed to create bitmap rep from image")
            return false
        }

        cursor.setRepresentation(bitmapRep, for: targetScale)
        appState.markAsChanged()

        // Trigger refresh - both local preview and cursor list
        localRefreshTrigger += 1
        appState.cursorListRefreshTrigger += 1

        print("Image imported successfully: \(bitmapRep.pixelsWide)x\(bitmapRep.pixelsHigh)")
        return true
    }

    /// Convert NSImage to NSBitmapImageRep
    private func createBitmapRep(from image: NSImage) -> NSBitmapImageRep? {
        // First try to get existing bitmap rep
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                return bitmapRep
            }
        }

        // Create new bitmap by drawing the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep
    }
}

// MARK: - Helper Tool Settings Section

import ServiceManagement

struct HelperToolSettingsView: View {
    private static let helperBundleIdentifier = "com.alexzielenski.mousecloakhelper"

    @State private var isHelperInstalled = false
    @State private var showInstallAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Helper Tool"

    var body: some View {
        Section("Helper Tool") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mousecape Helper")
                        .font(.headline)
                    Text(isHelperInstalled ? "Installed and running" : "Not installed")
                        .font(.caption)
                        .foregroundStyle(isHelperInstalled ? .green : .secondary)
                }

                Spacer()

                Button(isHelperInstalled ? "Uninstall" : "Install") {
                    toggleHelper()
                }
            }

            Text("The helper tool ensures cursors persist after logout/login and system updates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            checkHelperStatus()
        }
        .alert(alertTitle, isPresented: $showInstallAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func checkHelperStatus() {
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)
        isHelperInstalled = (service.status == .enabled)
    }

    private func toggleHelper() {
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)
        let shouldInstall = !isHelperInstalled

        do {
            if shouldInstall {
                try service.register()
                isHelperInstalled = true
                alertTitle = "Success"
                alertMessage = "The Mousecape helper was successfully installed."
            } else {
                try service.unregister()
                isHelperInstalled = false
                alertTitle = "Success"
                alertMessage = "The Mousecape helper was successfully uninstalled."
            }
        } catch {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
        }
        showInstallAlert = true
    }
}

// MARK: - Preview

#Preview {
    EditOverlayView(cape: CursorLibrary(name: "Test Cape", author: "Test"))
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
