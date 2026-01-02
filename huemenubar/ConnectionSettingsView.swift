import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(HueClient.self) var client

    var body: some View {
        switch client.bridgeState {

        case .paired:
            VStack(alignment: .leading, spacing: 8) {
                Text("Connected")
                    .font(.headline)

                Text("Bridge IP: \(client.bridgeIP)")
                    .font(.caption)
            }

        case .bridgeFound:
            VStack {
                Text("Bridge found. Press the button on the bridge to pair.")
                Button("Pair Bridge") {

                }
            }

        case .noBridge:
            VStack {
                Text("No bridge found")
                Button("Discover Bridge") {
                    Task {
                        await client.discoverBridge()
                    }
                }
                Text(client.status)
            }
        }
    }
    
}
