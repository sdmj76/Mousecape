//
//  MainView.swift
//  Mousecape
//
//  Main view with TabView navigation (Home / Settings)
//  Uses Liquid Glass design for macOS 26+
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isEditing {
            // When editing, show HomeView directly without TabView
            HomeView()
        } else {
            // Normal mode: show TabView
            TabView {
                Tab("Home", systemImage: "cursorarrow.click.2") {
                    HomeView()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
