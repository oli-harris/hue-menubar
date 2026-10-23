import SwiftUI

struct ScenesSettingsView: View {
    @Environment(HueClient.self) var client
    @State var selectedRoomID: String?
    // Shift/Cmd-click to select several scenes and drag them together
    @State var selectedSceneIDs: Set<String?> = []

    var body: some View {
        VStack {
            Text("Scenes").font(.title)

            if client.rooms.isEmpty {
                Spacer()
                Text(client.fetchStatus.isEmpty ? "No rooms found" : client.fetchStatus)
                Spacer()
            } else {
                Text("Drag to reorder. Scenes below the line are hidden from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    List(selection: $selectedRoomID) {
                        ForEach(client.rooms) { room in
                            Text(room.roomName).tag(room.id)
                        }
                        .onMove { client.moveRoom(from: $0, to: $1) }
                    }
                    .frame(width: 150)

                    if let room = client.rooms.first(where: { $0.id == selectedRoomID }) ?? client.rooms.first {
                        sceneList(room)
                    }
                }
            }

            Button("Refresh") {
                Task {
                    await client.refresh()
                }
            }
        }
        .onAppear {
            if selectedRoomID == nil {
                selectedRoomID = client.rooms.first?.id
            }
        }
    }

    private func sceneList(_ room: HueRoom) -> some View {
        List(selection: $selectedSceneIDs) {
            ForEach(Array(room.editorItems.enumerated()), id: \.element?.id) { index, scene in
                if let scene {
                    Text(scene.name)
                        .foregroundStyle(index > room.scenes.count ? .secondary : .primary)
                } else {
                    HStack {
                        VStack { Divider() }
                        Text("Disabled").font(.caption).foregroundStyle(.secondary)
                        VStack { Divider() }
                    }
                }
            }
            .onMove { client.moveScene(roomID: room.id, from: $0, to: $1) }
        }
    }
}
