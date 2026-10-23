import SwiftUI

struct ScenesSettingsView: View {
    @Environment(HueClient.self) var client
    @State var selectedRoomID: String?
    // Shift/Cmd-click to select several scenes and drag them together
    @State var selectedSceneIDs: Set<String?> = []

    var body: some View {
        VStack {
            if client.rooms.isEmpty {
                Spacer()
                Text(client.fetchStatus.isEmpty ? "No rooms found" : client.fetchStatus)
                Spacer()
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        caption("Rooms")
                        List(selection: $selectedRoomID) {
                            ForEach(client.rooms) { room in
                                Text(room.roomName).tag(room.id)
                            }
                            .onMove { client.moveRoom(from: $0, to: $1) }
                        }
                    }
                    .frame(width: 150)

                    if let room = client.rooms.first(where: { $0.id == selectedRoomID }) ?? client.rooms.first {
                        VStack(alignment: .leading) {
                            caption("Scenes in \(room.roomName)")
                            sceneList(room)
                        }
                    }
                }
            }

            HStack {
                caption("Drag to reorder. Shift-click to move several.")
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await client.refresh()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if selectedRoomID == nil {
                selectedRoomID = client.rooms.first?.id
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
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
                        Text("Hidden from menu").font(.caption).foregroundStyle(.secondary)
                        VStack { Divider() }
                    }
                }
            }
            .onMove { client.moveScene(roomID: room.id, from: $0, to: $1) }
        }
    }
}
