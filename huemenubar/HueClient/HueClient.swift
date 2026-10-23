import Foundation

// API Types

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


struct RoomsResponse: Decodable {
    let data: [RoomAPI]
}

struct RoomAPI: Decodable {
    let id: String
    let metadata: Metadata
    let services: [Service]
    
    struct Service: Decodable {
        let rid: String
        let rtype: String
    }
    
    struct Metadata: Decodable {
        let name: String
    }
}

struct ScenesResponse: Decodable {
    let data: [SceneAPI]
}

struct SceneAPI: Decodable {
    let id: String
    let metadata: Metadata
    let group: Group
    
    struct Metadata: Decodable {
        let name: String
    }
    
    struct Group: Decodable {
        let rid: String
        let rtype: String
    }
}

// Internal Types

enum HueBridgeState: String {
    case noBridge
    case bridgeFound
    case paired
}


typealias HueRooms = [HueRoom]

struct HueRoom: Identifiable, Codable {
    let id: String
    let groupedLightId: String
    let roomName: String
    var scenes: [HueScene]
}

struct HueScene: Identifiable, Codable {
    let id: String
    let name: String
}

struct StoredOrder {
    var roomOrder: [String]
    var sceneOrder: [String: [String]]
}


@Observable
final class HueClient {
    var bridgeStatus: String = ""
    var bridgeState: HueBridgeState = .noBridge
    
    var fetchStatus: String = ""
    
    var hueDelegate: HueTrustDelegate?
    var hueSession: URLSession = URLSession.shared
    
    var bridgeIP: String = ""
    var bridgeID: String = ""
    var username: String = ""
    
    var rooms: [HueRoom] = []

    init() {
        bridgeIP = UserDefaults.standard.string(forKey: "hueBridgeIP") ?? ""
        username = UserDefaults.standard.string(forKey: "hueUsername") ?? ""
        bridgeID = UserDefaults.standard.string(forKey: "hueBridgeID") ?? ""
        
        if (!bridgeIP.isEmpty && !username.isEmpty && !bridgeID.isEmpty) {
            bridgeState = .paired
            configureHueHTTPS(bridgeId: bridgeID)
        }
        
        Task {
            if (!bridgeIP.isEmpty && !username.isEmpty && !bridgeID.isEmpty) {
                await refresh()
            }
        }
    }
     
     func refresh() async {
        // Load stored order
        // Fetch rooms and scenes
        let freshRooms = await fetchScenesIntoRooms()
        self.rooms = freshRooms
        // Apply order based on order, new elements to Int.max
    }
    
    func configureHueHTTPS(bridgeId: String) {
        guard let d = HueTrustDelegate(bridgeId: bridgeId) else {
            self.bridgeStatus = "Delegate Failed"
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
        self.bridgeStatus = "Discovering Hue Bridge"
        
        let url = URL(string: "https://discovery.meethue.com")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                self.bridgeStatus = "Discovery failed (bad request)"
                return
            }
                
            let items = try JSONDecoder().decode([DiscoveryItem].self, from: data)
            guard let first = items.first else {
                self.bridgeStatus = "No bridge found"
                return
            }
            
            configureHueHTTPS(bridgeId: first.id)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = first.internalipaddress
            self.bridgeID = first.id
            self.bridgeStatus = "Press the button on bridge to pair"
        } catch {
            self.bridgeStatus = "Discovery failed"
        }
    }
    
    func setBridge(ip: String) async {
        func isValidIPv4Regex(_ ip: String) -> Bool {
            let pattern =
            #"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#
            return ip.range(of: pattern, options: .regularExpression) != nil
        }
        
        guard isValidIPv4Regex(ip) else {
            self.bridgeStatus = "Invalid IP address entered"
            return
        }
        
        self.bridgeStatus = "Connecting to Hue Bridge"
        
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
                self.bridgeStatus = "Failed to connect with Hue Bridge"
                return
            }
                
            let configBridge: ConfigBridge = try JSONDecoder().decode(ConfigBridge.self, from: data)

            configureHueHTTPS(bridgeId: configBridge.bridgeid)
            
            self.bridgeState = .bridgeFound
            self.bridgeIP = ip
            self.bridgeID = configBridge.bridgeid
            self.bridgeStatus = "Press the button on bridge to pair"
        } catch {
            self.bridgeStatus = "Could not find Hue Bridge"
        }
    }
    
    func pairBridge() async {
        self.bridgeStatus = "Pairing with Hue Bridge"
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
                self.bridgeStatus = "Pairing failed"
                print("Response not 200-300")
                return
            }
            
            let items = try JSONDecoder().decode([PairingItem].self, from: data)
            guard let first = items.first else {
                self.bridgeStatus = "Pairing failed"
                print("Decoding failed")
                return
            }
            
            if first.error != nil {
                self.bridgeStatus = "Press the button on bridge to pair"
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
            self.bridgeStatus = "Pairing failed"
            print("HTTP Error", error)
        }
    }
    
    private func fetchRooms() async -> HueRooms {
        guard self.bridgeState == HueBridgeState.paired else {
            self.fetchStatus = "No bridge paired"
            return []
}

        let url = URL(string: "https://\(self.bridgeIP)/clip/v2/resource/room")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.username, forHTTPHeaderField: "hue-application-key")
        
        do {
            let (data, response) = try await hueSession.data(for: request)
            
            let roomsResponse: RoomsResponse = try JSONDecoder().decode(RoomsResponse.self, from: data)
            
            let rooms: HueRooms = roomsResponse.data.map {
                HueRoom(
                    id: $0.id,
                    groupedLightId: $0.services.first { $0.rtype == "grouped_light" }?.rid ?? "",
                    roomName: $0.metadata.name,
                    scenes: []
                )
            }
            
            return rooms
        } catch {
            self.fetchStatus = "Error: \(error.localizedDescription)"
            return []
        }
    }
    
    private func fetchScenesIntoRooms() async -> HueRooms {
        guard self.bridgeState == HueBridgeState.paired else {
            self.fetchStatus = "No bridge paired"
            return []
        }
        
        let url = URL(string: "https://\(self.bridgeIP)/clip/v2/resource/scene")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.username, forHTTPHeaderField: "hue-application-key")
        
        do {
            let (data, response) = try await hueSession.data(for: request)
            
            let scenesResponse: ScenesResponse = try JSONDecoder().decode(ScenesResponse.self, from: data)
            
            let rooms = await fetchRooms()
            
            let updatedRooms = rooms.map { room in
                var updatedRoom = room
                updatedRoom.scenes = scenesResponse.data
                    .filter { $0.group.rid == room.id }
                    .map { HueScene(id: $0.id, name: $0.metadata.name) }
                return updatedRoom
            }
            
            return updatedRooms;
        } catch {
            self.fetchStatus = "Error: \(error.localizedDescription)"
            return []
        }
    }
    
    func activateScene(scene: HueScene) async {
        guard self.bridgeState == HueBridgeState.paired else {
            self.fetchStatus = "No bridge paired"
            return
        }
        
        let url = URL(string: "https://\(self.bridgeIP)/clip/v2/resource/scene/\(scene.id)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(self.username, forHTTPHeaderField: "hue-application-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["recall": ["action": "active"]])
        
        do {
            let (data, response) = try await hueSession.data(for: request)
        } catch {
        }
    }
    
    func turnOffRoom(room: HueRoom) async {
        guard self.bridgeState == HueBridgeState.paired else {
            self.fetchStatus = "No bridge paired"
            return
        }
        
        let url = URL(string: "https://\(self.bridgeIP)/clip/v2/resource/grouped_light/\(room.groupedLightId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(self.username, forHTTPHeaderField: "hue-application-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["on": ["on": false] ])
        
        do {
            let (data, response) = try await hueSession.data(for: request)
        } catch {
        }
    }
}
