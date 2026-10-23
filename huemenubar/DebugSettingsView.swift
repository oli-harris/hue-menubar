import SwiftUI

struct DebugSettingsView: View {
    @Environment(HueClient.self) var client

    var body: some View {
        VStack {
            Text("Debug Information").font(.title)
            Spacer()

            Form {
                LabeledContent("Bridge State", value: client.bridgeState.rawValue)
                if client.bridgeState == .paired {
                    LabeledContent("Connection", value: client.connection.rawValue)
                    LabeledContent("Rooms", value: "\(client.rooms.count)")
                }
                row("Bridge ID", client.bridgeID)
                row("Bridge IP", client.bridgeIP)
                row("Username", client.username)
                row("Bridge Status", client.bridgeStatus)
                row("Fetch Status", client.fetchStatus)
            }
            .textSelection(.enabled)
        }
    }

    // Hide values the client doesn't have yet
    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}
