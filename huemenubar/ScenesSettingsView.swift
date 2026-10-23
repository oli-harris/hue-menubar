import SwiftUI

struct ScenesSettingsView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        VStack {
            Text("Scenes").font(.title)
            
            Spacer()
            
            Group {
                if client.rooms.isEmpty {
                    Text(client.fetchStatus)
                } else {
                    ForEach(client.rooms) { room in
                        Text(room.roomName)
                        
                        ForEach(room.scenes) { scene in
                            Text(scene.name)
                        }
                        
                        Divider()
                    }
                }
            }

            Spacer()
            
            Button("Refresh") {
                Task {
                    await client.refresh()
                }
            }
        }
    }
}
