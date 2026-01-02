import SwiftUI

struct HueScenesView: View {
    var body: some View {
        // Title
        Text("Philips Hue").font(.headline)
        Divider()
        
        // Rooms
        Text("Bedroom")
        Divider()
        
        Text("Living Room")
        Divider()

        // App Control
        SettingsLink {
            Text("Settings")
        }.keyboardShortcut(",")
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}

#Preview {
    HueScenesView()
}
