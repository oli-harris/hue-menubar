import os
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        TabView {
            GeneralSettingsView()
            .tabItem {
                Label("General", systemImage:"gearshape")
            }

            BridgeSettingsView()
            .tabItem {
                Label("Bridge", systemImage:"network")
            }
                
            if client.bridgeState == .paired {
                ScenesSettingsView()
                .tabItem {
                    Label("Scenes Editor", systemImage:"sun.horizon")
                }
            }
            
            DebugSettingsView()
            .tabItem {
                Label("Developer", systemImage:"info.circle.text.page")
            }
            
        }.frame(width: 520, height: 400)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct GeneralSettingsView: View {
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
        let info = Bundle.main.infoDictionary
        VStack {
            Form {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: {
                        Self.setLaunchAtLogin($0)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
            }.formStyle(.grouped)
            
            Text("Hue Menubar \(info?["CFBundleShortVersionString"] as? String ?? "") (\(info?["CFBundleVersion"] as? String ?? ""))")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.bottom)
        }
    }
}

#Preview {
    SettingsView()
}
