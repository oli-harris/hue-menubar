import HueKit
import SwiftUI

// Menu content isn't rendered at launch, so first-launch setup is opened from here
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        HueClient.shared.startMonitoring()
        guard HueClient.shared.bridgeState != .paired else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct HueMenuBarApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    let client = HueClient.shared
    @AppStorage("hideWhenUnreachable") private var hideWhenUnreachable = false
    
    init() {
        // On by default, but only set once so turning it off sticks
        if !UserDefaults.standard.bool(forKey: "didSetDefaultLoginItem") {
            UserDefaults.standard.set(true, forKey: "didSetDefaultLoginItem")
            GeneralSettingsView.setLaunchAtLogin(true)
        }
    }
    
    var body: some Scene {
        // Simplified Menu Bar
        MenuBarExtra(isInserted: .constant(!(hideWhenUnreachable && client.connection == .unreachable))) {
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
