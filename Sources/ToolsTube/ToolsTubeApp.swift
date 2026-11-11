import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { SelfTest.runIfRequested(); Snapshot.runIfRequested() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ToolsTubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup("ToolsTube") {
            RootView()
                .environmentObject(app)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1080, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Ir") {
                ForEach(Array(MainTab.allCases.enumerated()), id: \.element) { i, t in
                    Button(t.label) { app.switchTab(t) }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
