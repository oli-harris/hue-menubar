import SwiftUI

struct HueScenesView: View {
    @Environment(HueClient.self) var client
    
    // Cmd-1…9 map to enabled scenes in menu order across all rooms; offsets[i] is room i's first number.
    var offsets: [Int] {
        client.rooms.reduce(into: [0]) { $0.append($0.last! + $1.scenes.count) }
    }

    var body: some View {
        let offsets = offsets
        // Title
        Text("Philips Hue").font(.headline)
        Divider()
        
        ForEach(Array(client.rooms.enumerated()), id: \.element.id) { roomIndex, room in
            Text(room.roomName)
            
            ForEach(Array(room.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                let number = offsets[roomIndex] + sceneIndex + 1
                Button() {
                    Task {
                        await client.activateScene(scene: scene)
                    }
                } label: {
                    Text(scene.name)
                }.keyboardShortcut(number <= 9 ? KeyboardShortcut(KeyEquivalent(Character("\(number)"))) : nil)
            }
            
            Button("Room Off") {
                Task {
                    await client.turnOffRoom(room: room)
                }
            }
            
            Divider()
        }

        Button("Lights Off") {
            Task {
                for room in client.rooms { await client.turnOffRoom(room: room) }
            }
        }.keyboardShortcut("0")
        
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
