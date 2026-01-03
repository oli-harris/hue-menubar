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

struct PairRequest: Encodable {
    let devicetype: String
    let generateclientkey: Bool
}

struct PairingItem : Decodable {
    let success: Success?
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

struct ConfigBridge: Decodable {
    let bridgeid: String
}



@Observable
final class HueClient {
    var status: String = ""
    var bridgeState: HueBridgeState = .noBridge
    var hueDelegate: HueTrustDelegate?
    var hueSession: URLSession = URLSession.shared
    var bridgeIP: String = ""
    var bridgeID: String = ""
    var username: String = ""
    var id: String = ""

    init() {
        bridgeIP = UserDefaults.standard.string(forKey: "hueBridgeIP") ?? ""
        username = UserDefaults.standard.string(forKey: "hueUsername") ?? ""
        id = UserDefaults.standard.string(forKey: "hueBridgeID") ?? ""
        
        if (!bridgeIP.isEmpty && !username.isEmpty && !id.isEmpty) {
            bridgeState = .paired
        }
    }
    
    func configureHueHTTPS(bridgeId: String) {
        guard let d = HueTrustDelegate(bridgeId: bridgeId) else {
            status = "Delegate Failed"
            return
        }

        self.hueDelegate = d

        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 6

        self.hueSession = URLSession(configuration: config, delegate: d, delegateQueue: nil)
    }
    
    func discoverBridge() async {
        self.status = "Discovering Hue Bridge"
        
        let url = URL(string: "https://discovery.meethue.com")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.status = "Discovery failed (bad request)"
                return
            }
                
            let items = try JSONDecoder().decode([DiscoveryItem].self, from: data)
            guard let first = items.first else {
                self.status = "No bridge found"
                return
            }
            
            configureHueHTTPS(bridgeId: first.id)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = first.internalipaddress
            self.bridgeID = first.id
            self.status = "Press the button on bridge to pair"
        } catch {
            self.status = "Discovery failed"
        }
    }
    
    func setBridge(ip: String) async {
        func isValidIPv4Regex(_ ip: String) -> Bool {
            let pattern =
            #"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#
            return ip.range(of: pattern, options: .regularExpression) != nil
        }
        
        guard isValidIPv4Regex(ip) else {
            self.status = "Invalid IP address entered"
            return
        }
        
        self.status = "Connecting to Hue Bridge"
        
        let url = URL(string: "http://\(ip)/api/0/config")!
        
        // Should timeout quickly if wrong ip entered
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        config.waitsForConnectivity = false
        config.connectionProxyDictionary = [:]
        
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.status = "Failed to connect with Hue Bridge"
                return
            }
                
            let configBridge: ConfigBridge = try JSONDecoder().decode(ConfigBridge.self, from: data)

            configureHueHTTPS(bridgeId: configBridge.bridgeid)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = ip
            self.bridgeID = configBridge.bridgeid
            self.status = "Press the button on bridge to pair"
        } catch {
            self.status = "Could not find Hue Bridge"
        }
    }
    
    func pairBridge() async {
        self.status = "Pairing with Hue Bridge"
        guard !bridgeIP.isEmpty else {
            self.bridgeState = .noBridge
            return
        }
        
        let url = URL(string: "https://\(self.bridgeIP)/api")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(
                PairRequest(
                    devicetype: "huemenubar",
                    generateclientkey: true
                )
            )
            
            let (data, response) = try await hueSession.data(for: request)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.status = "Pairing failed"
                print("Response not 200-300")
                return
            }
            
            let items = try JSONDecoder().decode([PairingItem].self, from: data)
            guard let first = items.first else {
                self.status = "Pairing failed"
                print("Decoding failed")
                return
            }
            
            if first.error != nil {
                self.status = "Press the button on bridge to pair"
                return
            }
            
            if let success = first.success {
                self.username = success.username
                print("Paired: ", self.username)
                self.bridgeState = .paired
                
                // Store State
                UserDefaults.standard.set(success.username, forKey: "hueUsername")
                UserDefaults.standard.set(self.bridgeID, forKey: "hueBridgeID")
                UserDefaults.standard.set(self.bridgeIP, forKey: "hueBridgeIP")
            }
        }
        catch {
            self.status = "Pairing failed"
            print("HTTP Error", error)
        }
    }
    

}
