import SwiftUI

struct HueScenesView: View {
    var body: some View {
        @State var scenes = getScenes()
        
        // Title
        Text("Philips Hue").font(.headline)
        Divider()
        
        // Scenes
        Text("Scenes").font(.subheadline)
        // Displays each scene with a keyboard shortcut from 1-9
        ForEach(Array(scenes.enumerated()), id:\.offset) { index, scene in
            Button(scene.name) {
                print("test")
            }.keyboardShortcut(KeyEquivalent(Character(String(index+1))))
        }
        
        
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
