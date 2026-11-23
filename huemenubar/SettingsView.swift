import os
import ServiceManagement
import HueKit
import SwiftUI

struct SettingsView: View {
    enum Tab { case general, bridge, scenes }
    
    @Environment(HueClient.self) var client
    @State private var tab = Tab.general
    
    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView()
            .tabItem {
                Label("General", systemImage:"gearshape")
            }
            .tag(Tab.general)

            BridgeSettingsView(onChooseScenes: { tab = .scenes })
            .tabItem {
                Label("Bridge", systemImage:"network")
            }
            .tag(Tab.bridge)
                
            if client.bridgeState == .paired {
                ScenesSettingsView()
                .tabItem {
                    Label("Scenes Editor", systemImage:"sun.horizon")
                }
                .tag(Tab.scenes)
            }
            
        }.frame(width: 520, height: 400)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            if client.bridgeState != .paired { tab = .bridge }
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("localNetworkOnly") private var localNetworkOnly = false
    @AppStorage("hideWhenUnreachable") private var hideWhenUnreachable = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    private static let log = Logger(subsystem: "com.harris.huemenubar", category: "Settings")
    
    static func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("Setting launch at login to \(on) failed: \(error)")
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                        VStack(alignment: .leading) {
                            Text("Hue Menubar").font(.headline)
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Toggle("Launch at login", isOn: Binding(
                        get: { launchAtLogin },
                        set: {
                            Self.setLaunchAtLogin($0)
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    ))
                }
                
                Section {
                    Toggle("Only use local network", isOn: $localNetworkOnly)
                    Text("Never contact the internet to look up the bridge; only the saved local address is used.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Hide menu icon when bridge is unreachable", isOn: $hideWhenUnreachable)
                    Text("The icon returns automatically once the bridge can be reached again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                Section {
                    Button("Copy install command") {
                        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/hue").path
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("ln -sf '\(helper)' /opt/homebrew/bin/hue", forType: .string)
                    }
                    Text("Adds a hue command for the terminal. Paste the copied command into Terminal; any folder on your PATH works in place of /opt/homebrew/bin.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text("Command line tool")
                }
            }.formStyle(.grouped)
        }
    }
}

#Preview {
    SettingsView()
}
