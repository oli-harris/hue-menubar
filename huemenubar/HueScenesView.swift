import SwiftUI

struct HueScenesView: View {
    @Environment(HueClient.self) var client
    @Environment(\.openSettings) private var openSettings
    
    // Cmd-1…9 map to enabled scenes in menu order across all rooms; offsets[i] is room i's first number.
    var offsets: [Int] {
        client.rooms.reduce(into: [0]) { $0.append($0.last! + $1.scenes.count) }
    }

    // LSUIElement apps open windows behind other apps unless activated first
    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
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
        
        if client.bridgeState != .paired {
            Button("Set Up Hue Bridge…", action: showSettings)
        } else {
            ForEach(Array(client.rooms.enumerated()).filter { !$0.element.scenes.isEmpty }, id: \.element.id) { roomIndex, room in
                Text(room.roomName)
                // Toggles render as checkmark items in an NSMenu
                ForEach(Array(room.scenes.enumerated()), id: \.element.id) { sceneIndex, scene in
                    let number = offsets[roomIndex] + sceneIndex + 1
                    Toggle(scene.name, isOn: Binding(
                        get: { room.activeSceneID == scene.id },
                        set: { _ in Task { await client.activateScene(scene: scene) } }
                    ))
                    .keyboardShortcut(number <= 9 ? KeyboardShortcut(KeyEquivalent(Character("\(number)"))) : nil)
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
        }
        
        Divider()

        // App Control
        if client.bridgeState == .paired {
            Button("Refresh") {
                Task { await client.refresh() }
            }.keyboardShortcut("r")
        }
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",", modifiers: .command)
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}

#Preview {
    HueScenesView()
}
