import SwiftUI

@main
struct HueMenuBarApp: App {
    let client = HueClient()
    
    var body: some Scene {
        // Simplified Menu Bar
        MenuBarExtra() {
            HueScenesView().environment(client)
        } label: {
            Image(systemName: "lightbulb.max.fill").symbolRenderingMode(.hierarchical)
        }
        
        // Settings
        Settings {
            SettingsView().environment(client)
        }
    }
}
