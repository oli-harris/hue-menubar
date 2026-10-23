import AppKit
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
    let status: Status?
    
    struct Status: Decodable {
        let active: String?     // inactive, static or dynamic_palette
    }
    
    struct Metadata: Decodable {
        let name: String
    }
    
    struct Group: Decodable {
        let rid: String
        let rtype: String
    }
}

// Internal Types

// Setup progress: what we have stored
enum HueBridgeState: String {
    case noBridge
    case bridgeFound
    case paired
}

// Reachability of a paired bridge, from the last request made to it
enum HueConnection: String {
    case checking
    case connected
    case unreachable
    case unauthorized
}


typealias HueRooms = [HueRoom]

struct HueRoom: Identifiable, Codable {
    let id: String
    let groupedLightId: String
    let roomName: String
    var scenes: [HueScene]                  // Enabled, in menu order
    var disabledScenes: [HueScene] = []
    var activeSceneID: String?
    
    // Scenes as edited in settings: enabled, nil as the divider, then disabled
    var editorItems: [HueScene?] {
        scenes.map(Optional.some) + [nil] + disabledScenes.map(Optional.some)
    }
}

struct HueScene: Identifiable, Codable {
    let id: String
    let name: String
}

struct StoredOrder: Codable {
    var roomOrder: [String] = []
    // Scene IDs per room, scenes after `disabledMarker` are hidden from the menu
    var sceneOrder: [String: [String]] = [:]
    
    static let disabledMarker = "---"
    
    // Unknown rooms go last, new scenes go to the bottom of the enabled scenes
    func apply(to rooms: [HueRoom]) -> [HueRoom] {
        let ordered = roomOrder.compactMap { id in rooms.first { $0.id == id } }
            + rooms.filter { !roomOrder.contains($0.id) }
        
        return ordered.map { room in
            var room = room
            let all = room.scenes + room.disabledScenes
            let stored = sceneOrder[room.id] ?? []
            let split = stored.firstIndex(of: Self.disabledMarker) ?? stored.count
            let pick = { (ids: ArraySlice<String>) in ids.compactMap { id in all.first { $0.id == id } } }
            
            room.scenes = pick(stored[..<split]) + all.filter { !stored.contains($0.id) }
            room.disabledScenes = pick(stored[split...].dropFirst())
            return room
        }
    }
}


@MainActor
@Observable
final class HueClient {
    var bridgeStatus: String = ""
    var bridgeState: HueBridgeState = .noBridge
    var connection: HueConnection = .checking
    var isPairing = false
    
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
            Task { await refresh() }
        }

        // refresh() guards on pairing, so this also picks up a later pair
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5)) // Wi-Fi is usually not back yet
                await self?.refresh()
            }
        }
    }
    
    func refresh() async {
        guard bridgeState == .paired else {
            fetchStatus = "No bridge paired"
            return
        }
        
        do {
            let roomsData = try await send("room")
            let scenesData = try await send("scene")
            let rooms = try JSONDecoder().decode(RoomsResponse.self, from: roomsData).data
            let scenes = try JSONDecoder().decode(ScenesResponse.self, from: scenesData).data
            
            self.rooms = loadOrder().apply(to: rooms.map { room in
                HueRoom(
                    id: room.id,
                    groupedLightId: room.services.first { $0.rtype == "grouped_light" }?.rid ?? "",
                    roomName: room.metadata.name,
                    scenes: scenes
                        .filter { $0.group.rid == room.id }
                        .map { HueScene(id: $0.id, name: $0.metadata.name) },
                    activeSceneID: scenes.first { $0.group.rid == room.id && $0.status?.active.map { $0 != "inactive" } == true }?.id
                )
            })
            fetchStatus = ""
        } catch {
            // Keep the last known rooms rather than emptying the menu
            fetchStatus = "Error: \(error.localizedDescription)"
        }
    }
    
    func moveRoom(from: IndexSet, to: Int) {
        rooms.move(fromOffsets: from, toOffset: to)
        saveOrder()
    }
    
    // Moves within a room's editorItems; dragging across the divider enables/disables a scene
    func moveScene(roomID: String, from: IndexSet, to: Int) {
        guard let i = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        
        var items = rooms[i].editorItems
        items.move(fromOffsets: from, toOffset: to)
        let split = items.firstIndex { $0 == nil }!
        
        rooms[i].scenes = items[..<split].compactMap { $0 }
        rooms[i].disabledScenes = items[(split + 1)...].compactMap { $0 }
        saveOrder()
    }
    
    private func loadOrder() -> StoredOrder {
        guard let data = UserDefaults.standard.data(forKey: "hueOrder"),
              let order = try? JSONDecoder().decode(StoredOrder.self, from: data) else {
            return StoredOrder()
        }
        return order
    }
    
    private func saveOrder() {
        var order = loadOrder()
        order.roomOrder = rooms.map(\.id)
        for room in rooms {
            order.sceneOrder[room.id] = room.scenes.map(\.id) + [StoredOrder.disabledMarker] + room.disabledScenes.map(\.id)
        }
        
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: "hueOrder")
        }
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

        // Sessions retain their delegate until invalidated (no-op on .shared)
        hueSession.finishTasksAndInvalidate()
        self.hueSession = URLSession(configuration: config, delegate: d, delegateQueue: nil)
    }
    
    func unpair() {
        for key in ["hueBridgeIP", "hueUsername", "hueBridgeID"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        hueSession.finishTasksAndInvalidate()
        hueSession = URLSession.shared
        hueDelegate = nil
        
        bridgeIP = ""
        bridgeID = ""
        username = ""
        rooms = []
        bridgeStatus = ""
        fetchStatus = ""
        connection = .checking
        bridgeState = .noBridge
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
        guard !bridgeIP.isEmpty else {
            self.bridgeState = .noBridge
            return
        }

        isPairing = true
        defer { isPairing = false }

        // The link button stays active for 30s after being pressed, so keep trying for that long
        let deadline = Date().addingTimeInterval(30)
        bridgeStatus = "Press the button on the bridge"
        while bridgeState == .bridgeFound, Date() < deadline {
            if await attemptPair() { return }
            try? await Task.sleep(for: .seconds(2))
        }

        if bridgeState == .bridgeFound {
            bridgeStatus = "Timed out. Press the bridge button, then Pair Bridge"
        }
    }

    // Returns true when finished (paired or failed), false when the link button hasn't been pressed yet
    private func attemptPair() async -> Bool {
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
                return true
            }

            let items = try JSONDecoder().decode([PairingItem].self, from: data)
            guard let first = items.first else {
                self.bridgeStatus = "Pairing failed"
                print("Decoding failed")
                return true
            }

            if let error = first.error {
                // 101: link button not pressed
                guard error.type == 101 else {
                    self.bridgeStatus = "Pairing failed: \(error.description)"
                    return true
                }
                return false
            }

            // Cancelled while the request was in flight
            guard bridgeState == .bridgeFound else { return true }

            if let success = first.success {
                self.username = success.username
                print("Paired: ", self.username)
                self.connection = .checking
                self.bridgeState = .paired
                
                // Store State
                UserDefaults.standard.set(success.username, forKey: "hueUsername")
                UserDefaults.standard.set(self.bridgeID, forKey: "hueBridgeID")
                UserDefaults.standard.set(self.bridgeIP, forKey: "hueBridgeIP")
                
                await refresh()
            }
            return true
        }
        catch {
            self.bridgeStatus = "Pairing failed"
            print("HTTP Error", error)
            return true
        }
    }
    
    // All v2 calls go through here so `connection` always reflects the last response
    private func send(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard bridgeState == .paired else { throw URLError(.userAuthenticationRequired) }

        var request = URLRequest(url: URL(string: "https://\(bridgeIP)/clip/v2/resource/\(path)")!)
        request.httpMethod = method
        request.setValue(username, forHTTPHeaderField: "hue-application-key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let data: Data, response: URLResponse
        do {
            (data, response) = try await hueSession.data(for: request)
        } catch {
            connection = .unreachable
            throw error
        }
        
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 {
            connection = .unauthorized
            throw URLError(.userAuthenticationRequired)
        }
        
        connection = .connected
        guard (200..<300).contains(code) else { throw URLError(.badServerResponse) }
        return data
    }
    
    func activateScene(scene: HueScene) async {
        let body = try? JSONEncoder().encode(["recall": ["action": "active"]])
        // Optimistic: show the checkmark before the bridge responds
        if let i = rooms.firstIndex(where: { $0.scenes.contains { $0.id == scene.id } }) {
            rooms[i].activeSceneID = scene.id
        }
        _ = try? await send("scene/\(scene.id)", method: "PUT", body: body)
    }
    
    func turnOffRoom(room: HueRoom) async {
        let body = try? JSONEncoder().encode(["on": ["on": false]])
        if let i = rooms.firstIndex(where: { $0.id == room.id }) { rooms[i].activeSceneID = nil }
        _ = try? await send("grouped_light/\(room.groupedLightId)", method: "PUT", body: body)
    }
}
