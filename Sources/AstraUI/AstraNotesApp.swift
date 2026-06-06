import SwiftUI
import AppKit

final class AstraNotesAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure SwiftPM-launched app windows receive keyboard focus as a foreground app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let url = Bundle.module.url(forResource: "AstraNotes_Logo", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
}

@main
struct AstraNotesApp: App {
    @NSApplicationDelegateAdaptor(AstraNotesAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
