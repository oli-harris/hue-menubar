import SwiftUI

@main
struct huemenubarApp: App {    
    var body: some Scene {
        // MenuBar
        MenuBarExtra() {
            HueScenesView()
        } label: {
            Image(systemName: "lightbulb.max.fill").symbolRenderingMode(.hierarchical)
        }
        
        // Settings
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
        
    }
}
