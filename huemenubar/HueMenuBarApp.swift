import SwiftUI

@main
struct HueMenuBarApp: App {
    let client = HueClient()
    
    init() {
        // On by default, but only set once so turning it off sticks
        if !UserDefaults.standard.bool(forKey: "didSetDefaultLoginItem") {
            UserDefaults.standard.set(true, forKey: "didSetDefaultLoginItem")
            GeneralSettingsView.setLaunchAtLogin(true)
        }
    }
    
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
