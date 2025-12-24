//
//  MainView.swift
//  Mousecape
//
//  Main view with page switcher (Home / Settings)
//  Uses Liquid Glass design for macOS 26+
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        @Bindable var appState = appState

        // Content (no transition here - handled inside HomeView)
        Group {
            switch appState.currentPage {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            }
        }
        // Toolbar in title bar area
        .toolbar {
            // Left: Page switcher or Back button
            ToolbarItem(placement: .navigation) {
                if appState.isEditing {
                    // Edit mode: Back button
                    Button(action: { appState.requestCloseEdit() }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .help("Back")
                } else {
                    // Normal mode: Page switcher
                    Picker(selection: $appState.currentPage) {
                        ForEach(AppPage.allCases) { page in
                            Text(localization.localized(page.title))
                                .tag(page)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            // Center: Title or Spacer
            ToolbarItem(placement: .principal) {
                if appState.isEditing, let cape = appState.editingCape {
                    Text("Edit: \(cape.name)")
                        .font(.headline)
                } else {
                    Spacer()
                }
            }
            .sharedBackgroundVisibility(.hidden)

            // Right: Action buttons
            if appState.isEditing {
                // Edit mode buttons
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        appState.showCapeInfo.toggle()
                        if appState.showCapeInfo {
                            appState.editingSelectedCursor = nil
                        }
                    }) {
                        Image(systemName: appState.showCapeInfo ? "info.circle.fill" : "info.circle")
                    }
                    .help("Cape Info")

                    Button(action: {
                        if let cape = appState.editingCape {
                            appState.saveCape(cape)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Save")
                }
            } else if appState.currentPage == .home {
                // Home page buttons
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { appState.createNewCape() }) {
                        Image(systemName: "plus")
                    }
                    .help("New Cape")

                    Button(action: { appState.importCape() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Cape")

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.applyCape(cape)
                        }
                    }) {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Apply Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.editCape(cape)
                        }
                    }) {
                        Image(systemName: "pencil")
                    }
                    .help("Edit Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.exportCape(cape)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(role: .destructive, action: {
                        if let cape = appState.selectedCape {
                            appState.confirmDeleteCape(cape)
                        }
                    }) {
                        Image(systemName: "trash")
                    }
                    .help("Delete Cape")
                    .disabled(appState.selectedCape == nil)
                }
            }
        }
        // Delete confirmation dialog
        .confirmationDialog(
            localization.localized("Delete Cape"),
            isPresented: $appState.showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: appState.capeToDelete
        ) { cape in
            Button("\(localization.localized("Delete")) \"\(cape.name)\"", role: .destructive) {
                appState.deleteCape(cape)
            }
            Button(localization.localized("Cancel"), role: .cancel) {
                appState.capeToDelete = nil
            }
        } message: { cape in
            Text("\(localization.localized("Are you sure you want to delete")) \"\(cape.name)\"? \(localization.localized("This action cannot be undone."))")
        }
        // Discard changes confirmation alert (macOS native style)
        .alert(
            localization.localized("Unsaved Changes"),
            isPresented: $appState.showDiscardConfirmation
        ) {
            Button(localization.localized("Save")) {
                appState.closeEditWithSave()
            }
            .keyboardShortcut(.defaultAction)

            Button(localization.localized("Don't Save"), role: .destructive) {
                appState.closeEdit()
            }

            Button(localization.localized("Cancel"), role: .cancel) {
                appState.showDiscardConfirmation = false
            }
        } message: {
            Text(localization.localized("Do you want to save the changes you made?"))
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
