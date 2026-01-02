import SwiftUI

struct HueScenesView: View {
    var body: some View {
        // Title
        Text("Philips Hue").font(.headline)
        Divider()
        
        // Rooms
        // Title
        Text("Bedroom")
        Divider()
        
        // Title
        Text("Living Room")
        Divider()

        // Quit
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}

#Preview {
    HueScenesView()
}
