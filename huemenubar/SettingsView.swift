import SwiftUI

struct SettingsView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        TabView {
            BridgeSettingsView()
            .tabItem {
                Label("Bridge Connection", systemImage:"network")
            }
                
            ScenesSettingsView()
            .tabItem {
                Label("Scenes Editor", systemImage:"sun.horizon")
            }
            
            DebugSettingsView()
            .tabItem {
                Label("Developer", systemImage:"info.circle.text.page")
            }
            
        }.frame(minWidth:450, minHeight:250).padding()
    }
}

#Preview {
    SettingsView()
}
