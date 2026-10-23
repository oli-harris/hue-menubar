import SwiftUI

struct DebugSettingsView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        VStack {
            Text("Debug Information").font(.title)
            Spacer()
            Text("").font(.caption).textSelection(.enabled)
            
            Text("Bridge ID: \(client.bridgeID)")
                .font(.caption).textSelection(.enabled)
            Text("Bridge IP: \(client.bridgeIP)")
                .font(.caption)
            Text("Username: \(client.username)")
                .font(.caption).textSelection(.enabled)
        }
    }
}
