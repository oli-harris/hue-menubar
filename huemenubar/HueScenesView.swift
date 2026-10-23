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
        if client.bridgeState == .paired {
            switch client.connection {
            case .unreachable: Text("Bridge unreachable")
            case .unauthorized: Text("Bridge rejected this app")
            default: EmptyView()
            }
        }
        Divider()
        
        ForEach(Array(client.rooms.enumerated()).filter { !$0.element.scenes.isEmpty }, id: \.element.id) { roomIndex, room in
            Section(room.roomName) {
                Picker(room.roomName, selection: Binding(
                    get: { room.activeSceneID },
                    set: { id in
                        if let scene = room.scenes.first(where: { $0.id == id }) {
                            Task { await client.activateScene(scene: scene) }
                        }
                    }
                )) {
                    ForEach(Array(room.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                        let number = offsets[roomIndex] + sceneIndex + 1
                        Text(scene.name)
                            .keyboardShortcut(number <= 9 ? KeyboardShortcut(KeyEquivalent(Character("\(number)"))) : nil)
                            .tag(Optional(scene.id))
                    }
                }.pickerStyle(.inline).labelsHidden()
                
                Button("Room Off") {
                    Task {
                        await client.turnOffRoom(room: room)
                    }
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
