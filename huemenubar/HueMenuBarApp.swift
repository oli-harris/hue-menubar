import SwiftUI

@main
struct huemenubarApp: App {    
    var body: some Scene {
        // Simplified Menu Bar
        MenuBarExtra() {
            HueScenesView()
        } label: {
            Image(systemName: "lightbulb.max.fill").symbolRenderingMode(.hierarchical)
        }
        
        // Settings
        Settings {
            SettingsView()
        }
    }
}
