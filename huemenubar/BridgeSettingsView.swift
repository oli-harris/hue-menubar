import SwiftUI

struct BridgeSettingsView: View {
    @Environment(HueClient.self) var client
    @State var manualEntry = false
    @State var ipEntry = ""
    @State var confirmUnpair = false
    
    var body: some View {
        switch client.bridgeState {

        case .paired:
            VStack {
                switch client.connection {
                case .checking:
                    Text("Connecting to Hue Bridge").font(.title)
                    ProgressView().controlSize(.small).padding(2)
                case .connected:
                    Text("Connected to Hue Bridge ☀️").font(.title)
                case .unreachable:
                    Text("Hue Bridge unreachable").font(.title)
                    Text("Paired, but can't reach the bridge at \(client.bridgeIP). Check it's powered on and on this network.")
                        .multilineTextAlignment(.center).padding(2)
                case .unauthorized:
                    Text("Hue Bridge rejected this app").font(.title)
                    Text("The pairing is no longer valid. Unpair and pair again.")
                        .multilineTextAlignment(.center).padding(2)
                }

                Spacer()

                HStack {
                    if client.connection == .unreachable {
                        Button("Retry") {
                            client.connection = .checking
                            Task {
                                await client.refresh()
                            }
                        }
                    }

                    Button("Unpair Bridge", role: .destructive) {
                        confirmUnpair = true
                    }
                }
            }
            .confirmationDialog("Unpair from Hue Bridge?", isPresented: $confirmUnpair) {
                Button("Unpair", role: .destructive) {
                    client.unpair()
                }
            } message: {
                Text("You'll need to press the bridge button to pair again.")
            }

        case .bridgeFound:
            VStack {
                Text("Hue Bridge found!").font(.title)
                Text(client.bridgeStatus).padding(2)
                if client.isPairing {
                    ProgressView().controlSize(.small)
                }

                Spacer()

                HStack {
                    Button("Cancel") {
                        client.unpair()
                    }

                    Button("Pair Bridge") {
                        Task {
                            await client.pairBridge()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(client.isPairing)
                }
            }
        
                    
        case .noBridge:
            VStack {
                Text("Connect a Hue Bridge").font(.title)
                Text(client.bridgeStatus).padding(2)
                
                Spacer()
                
                
                if manualEntry {
                    VStack(spacing: 12) {
                        TextField("Bridge IP", text:$ipEntry)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                        
                        HStack {
                            Button("Back") {
                                Task {
                                    manualEntry = false
                                }
                            }
                            
                            Button("Search") {
                                Task {
                                    await client.setBridge(ip: ipEntry)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Button("Enter IP") {
                            manualEntry = true
                        }
                        
                        Button("Search") {
                            Task {
                                await client.discoverBridge()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
            }
        }
    }
    
}
