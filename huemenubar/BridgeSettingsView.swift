import SwiftUI

struct BridgeSettingsView: View {
    @Environment(HueClient.self) var client
    @State var manualEntry = false
    @State var ipEntry = ""
    
    var body: some View {
        switch client.bridgeState {

        case .paired:
            VStack {
                Text("Connected to Hue Bridge").font(.title)
                
                Spacer()
                
                Text("Bridge IP: \(client.bridgeIP)")
                    .font(.caption)
            }

        case .bridgeFound:
            VStack {
                Text("Hue Bridge found!").font(.title)
                Text(client.status).padding(2)
                
                Spacer()
                
                Button("Pair Bridge") {
                    Task {
                        await client.pairBridge()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        
                    
        case .noBridge:
            VStack {
                Text("Connect a Hue Bridge").font(.title)
                Text(client.status).padding(2)
                
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
