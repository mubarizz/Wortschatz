import SwiftUI
import AppIntents

@main
struct WortschatzApp: App {
    init() {
        WortschatzShortcutsProvider.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
