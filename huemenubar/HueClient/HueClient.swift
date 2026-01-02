import Foundation

enum HueBridgeState: String {
    case noBridge
    case bridgeFound
    case paired
}

struct DiscoveryItem: Decodable {
    let id: String
    let internalipaddress: String
}

struct PairingItem : Decodable {
    let sucesss: Success?
    let error: Error?
    
    struct Success: Decodable {
        let username: String
        let clientkey: String
    }
    
    struct Error: Decodable {
        let type: Int
        let address: String
        let description: String
    }
}


@Observable
class HueClient {
    var status: String = ""
    var bridgeState: HueBridgeState = .noBridge
    var connected: Bool = false
    var bridgeIP: String = ""
    var username: String = ""
    var id: String = ""

    init() {
        bridgeIP = UserDefaults.standard.string(forKey: "bridgeIP") ?? ""
        username = UserDefaults.standard.string(forKey: "hueUsername") ?? ""
        
        // Check if bridge Exists
        if (!bridgeIP.isEmpty) {
            bridgeState = .bridgeFound
            
            // Attempt connect
        }
    }
    
    func discoverBridge() async {
        self.status = "Discovering Bridge"
        self.bridgeState = .noBridge
        
        let url = URL(string: "https://discovery.meethue.com")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.status = "Discovery failed"
                return
            }
                
            let items = try JSONDecoder().decode([DiscoveryItem].self, from: data)
            
            guard let first = items.first else {
                self.status = "No bridge found"
                return
            }
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = first.internalipaddress
            self.status = "Bridge found"
        } catch {
            self.status = "Discovery failed"
        }
    }
    
    func pairBridge() async {
        
    }
}
