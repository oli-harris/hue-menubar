import ServiceManagement
import SwiftUI

struct BridgeSettingsView: View {
    @Environment(HueClient.self) var client
    @State var manualEntry = false
    @State var ipEntry = ""
    @State var confirmUnpair = false
    @State var showUsername = false
    @State var searching = true
    @State var skipAutoSearch = false
    @State var justPaired = false
    @State var launchAtLogin = SMAppService.mainApp.status == .enabled
    var onChooseScenes: () -> Void = {}
    
    var body: some View {
        Group {
            switch client.bridgeState {
            case .paired:
                if justPaired { doneStep } else { pairedForm }
            case .bridgeFound: pairStep
            case .noBridge: findStep
            }
        }
        .onChange(of: client.bridgeState) { old, new in
            if old == .bridgeFound && new == .paired { justPaired = true }
        }
    }

    private var pairedForm: some View {
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
    }

    // Step 1: discover automatically, fall back to a manual IP
    private var findStep: some View {
        step("wifi", "Find your bridge", searching ? "Searching your network…" : client.bridgeStatus, index: 0) {
            if searching {
                ProgressView().controlSize(.small)
            } else if manualEntry {
                HStack {
                    TextField("Bridge IP", text: $ipEntry).textFieldStyle(.roundedBorder).frame(width: 180)
                    Button("Connect") { search { await client.setBridge(ip: ipEntry) } }
                        .buttonStyle(.borderedProminent)
                }
                Button("Search again") { manualEntry = false; search { await client.discoverBridge() } }
                    .buttonStyle(.borderless)
            } else {
                Button("Search again") { search { await client.discoverBridge() } }
                    .buttonStyle(.borderedProminent)
                Button("Enter IP address…") { manualEntry = true }
                    .buttonStyle(.borderless)
            }
        }
        .task {
            if skipAutoSearch {
                skipAutoSearch = false
                searching = false
            } else {
                await runSearch { await client.discoverBridge() }
            }
        }
    }

    private func search(_ action: @escaping () async -> Void) {
        Task { await runSearch(action) }
    }

    private func runSearch(_ action: () async -> Void) async {
        searching = true
        await action()
        searching = false
    }

    // Step 2: pairing starts by itself, the user only has to press the bridge button
    private var pairStep: some View {
        step("button.programmable", "Bridge found!", client.bridgeStatus, index: 1) {
            if client.isPairing {
                ProgressView().controlSize(.small)
            } else {
                Button("Try again") { Task { await client.pairBridge() } }
                    .buttonStyle(.borderedProminent)
            }
            Button("Cancel") { skipAutoSearch = true; client.unpair() }
                .buttonStyle(.borderless)
        }
        .task { await client.pairBridge() }
    }

    // Step 3
    private var doneStep: some View {
        step("checkmark.circle.fill", "You're all set", "Your rooms and scenes are in the menu bar.", index: 2, color: .green) {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: {
                    GeneralSettingsView.setLaunchAtLogin($0)
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            ))
            HStack {
                Button("Choose scenes") { justPaired = false; onChooseScenes() }
                Button("Done") { justPaired = false }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func step<Content: View>(_ symbol: String, _ title: String, _ subtitle: String, index: Int,
                                     color: Color = .accentColor, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(color)
            Text(title).font(.title2)
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
            content()
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3) { Circle().fill($0 == index ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 6, height: 6) }
            }
        }.padding()
    }
}
