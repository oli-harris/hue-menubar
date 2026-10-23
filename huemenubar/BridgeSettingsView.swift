import SwiftUI

struct BridgeSettingsView: View {
    @Environment(HueClient.self) var client
    @State var manualEntry = false
    @State var ipEntry = ""
    @State var confirmUnpair = false
    @State var showUsername = false
    
    var body: some View {
        switch client.bridgeState {

        case .paired:
            VStack {
                Form {
                    LabeledContent("Status") {
                        HStack {
                            switch client.connection {
                            case .checking: Circle().fill(.gray).frame(width: 8, height: 8); Text("Connecting…"); ProgressView().controlSize(.small)
                            case .connected: Circle().fill(.green).frame(width: 8, height: 8); Text("Connected")
                            case .unreachable: Circle().fill(.orange).frame(width: 8, height: 8); Text("Unreachable")
                            case .unauthorized: Circle().fill(.red).frame(width: 8, height: 8); Text("Rejected")
                            }
                        }
                    }
                    
                    if client.connection == .unreachable {
                        Text("Paired, but can't reach the bridge at \(client.bridgeIP). Check it's powered on and on this network.")
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            client.connection = .checking
                            Task {
                                await client.refresh()
                            }
                        }
                    } else if client.connection == .unauthorized {
                        Text("The pairing is no longer valid. Unpair and pair again.")
                            .foregroundStyle(.secondary)
                    }
                    
                    LabeledContent("IP address", value: client.bridgeIP).textSelection(.enabled)
                    LabeledContent("Bridge ID", value: client.bridgeID).textSelection(.enabled)
                    LabeledContent("Username") {
                        HStack {
                            if showUsername {
                                Text(client.username).textSelection(.enabled)
                            } else {
                                Text("••••••••")
                            }
                            Button {
                                showUsername.toggle()
                            } label: {
                                Image(systemName: showUsername ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(showUsername ? "Hide username" : "Show username")
                        }
                    }
                    LabeledContent("Last refresh") {
                        if let date = client.lastRefresh {
                            Text(date, format: .relative(presentation: .named))
                        } else {
                            Text("Never")
                        }
                    }
                    LabeledContent("Rooms", value: "\(client.rooms.count)")
                }.formStyle(.grouped)

                HStack {
                    Spacer()
                    Button("Unpair Bridge…", role: .destructive) {
                        confirmUnpair = true
                    }.foregroundStyle(.red)
                }.padding([.horizontal, .bottom])
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
            }.padding()
        
                    
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
                
            }.padding()
        }
    }
    
}
