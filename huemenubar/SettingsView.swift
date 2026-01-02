import SwiftUI

struct SettingsView: View {
    @Environment(HueClient.self) var client
    
    var body: some View {
        TabView {
            ConnectionSettingsView()
            .tabItem {
                Label("Connection", systemImage:"server.rack")
            }
                
            ScenesSettingsView()
            .tabItem {
                Label("Scenes", systemImage:"sun.horizon")
            }
            
        }.frame(minWidth:450, minHeight:250).padding()
    }
}

#Preview {
    SettingsView()
}
