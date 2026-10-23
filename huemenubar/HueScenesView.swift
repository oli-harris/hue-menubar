import SwiftUI

struct HueScenesView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        // Title
        Text("Philips Hue").font(.headline)
        Divider()
        
        ForEach(client.rooms) { room in
            Text(room.roomName)
            
            ForEach(room.scenes) { scene in
                Button() {
                    Task {
                        await client.activateScene(scene: scene)
                    }
                } label: {
                    Text(scene.name)
                }
            }
            
            Button("Lights Off") {
                Task {
                    await client.turnOffRoom(room: room)
                }
            }
            
            Divider()
        }

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
