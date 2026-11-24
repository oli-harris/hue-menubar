import AppKit
import Foundation
import Network
import os
import SwiftUI

@MainActor
@Observable
public final class HueClient {
    public internal(set) var bridgeStatus: String = ""
    public internal(set) var bridgeState: HueBridgeState = .noBridge
    public var connection: HueConnection = .checking
    public internal(set) var isPairing = false
    
    public internal(set) var fetchStatus: String = ""
    
    var hueDelegate: HueTrustDelegate?
    var hueSession: URLSession = URLSession.shared
    
    public internal(set) var bridgeIP: String = ""
    public internal(set) var bridgeID: String = ""
    public internal(set) var username: String = ""
    
    // Shared so the app delegate can check pairing at launch
    public static let shared = HueClient()

    public internal(set) var rooms: [HueRoom] = []
    public internal(set) var unassignedLights: [HueLight] = []   // Lights that aren't in any room
    public internal(set) var lastRefresh: Date?

    // The bridge_home grouped_light, the target of HueTarget.all
    @ObservationIgnored var allGroupedLightId: String?
    @ObservationIgnored var sceneActions: [String: [SceneAPI.ActionEntry]] = [:]

    static let rateLimitDelays: [Duration?] = [.milliseconds(300), .seconds(1)]
    static let log = Logger(subsystem: "com.harris.huemenubar", category: "HueClient")
    private let pathMonitor = NWPathMonitor()

    init() {
        bridgeIP = UserDefaults.standard.string(forKey: "hueBridgeIP") ?? ""
        username = UserDefaults.standard.string(forKey: "hueUsername") ?? ""
        bridgeID = UserDefaults.standard.string(forKey: "hueBridgeID") ?? ""
        
        if (!bridgeIP.isEmpty && !username.isEmpty && !bridgeID.isEmpty) {
            bridgeState = .paired
            configureHueHTTPS(bridgeId: bridgeID)
        }
    }

    // Background refresh for a long-lived app; one-shot callers (a CLI) skip this
    public func startMonitoring() {
        Task { await refresh() }

        // refresh() guards on pairing, so this also picks up a later pair
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
        // Re-check when the network changes so a hidden icon can come back (first callback is the current state)
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        pathMonitor.start(queue: .main)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5)) // Wi-Fi is usually not back yet
                await self?.refresh()
            }
        }
    }
    
    public func refresh(rediscover: Bool = true) async {
        guard bridgeState == .paired else {
            fetchStatus = "No bridge paired"
            return
        }
        
        do {
            async let roomsData = send("room")
            async let scenesData = send("scene")
            async let lightsData = send("light")
            async let groupsData = send("grouped_light")
            async let homeData = send("bridge_home")
            let decoder = JSONDecoder()
            let rooms = try decoder.decode(RoomsResponse.self, from: await roomsData).data
            let scenes = try decoder.decode(ScenesResponse.self, from: await scenesData).data
            let lights = try decoder.decode(LightsResponse.self, from: await lightsData).data
            let groups = try decoder.decode(GroupedLightsResponse.self, from: await groupsData).data
            let home = try decoder.decode(BridgeHomeResponse.self, from: await homeData).data
            
            let built = assemble(rooms: rooms, scenes: scenes, lights: lights, groups: groups, aliases: loadAliases())
            self.rooms = loadOrder().apply(to: built.rooms)
            unassignedLights = built.unassigned
            allGroupedLightId = home.first?.services.first { $0.rtype == "grouped_light" }?.rid
            sceneActions = Dictionary(uniqueKeysWithValues: scenes.map { ($0.id, $0.actions ?? []) })
            fetchStatus = ""
            lastRefresh = Date()
        } catch {
            // Keep the last known rooms rather than emptying the menu
            fetchStatus = "Error: \(error.localizedDescription)"
            Self.log.error("Refresh failed: \(error)")
            // The router may have given the bridge a new IP; retry once at most
            if rediscover, connection == .unreachable, !UserDefaults.standard.bool(forKey: "localNetworkOnly"), await updateBridgeIP() {
                await refresh(rediscover: false)
            }
        }
    }
    
    // Returns true when discovery found the paired bridge at a different IP
    private func updateBridgeIP() async -> Bool {
        guard let (data, _) = try? await URLSession.shared.data(from: URL(string: "https://discovery.meethue.com")!),
              let items = try? JSONDecoder().decode([DiscoveryItem].self, from: data),
              let item = items.first(where: { $0.id.caseInsensitiveCompare(bridgeID) == .orderedSame }),
              item.internalipaddress != bridgeIP else { return false }
        
        Self.log.info("Bridge IP changed from \(self.bridgeIP) to \(item.internalipaddress)")
        bridgeIP = item.internalipaddress
        UserDefaults.standard.set(bridgeIP, forKey: "hueBridgeIP")
        return true
    }
    
    public func moveRoom(from: IndexSet, to: Int) {
        rooms.move(fromOffsets: from, toOffset: to)
        saveOrder()
    }
    
    // Moves within a room's editorItems; dragging across the divider enables/disables a scene
    public func moveScene(roomID: String, from: IndexSet, to: Int) {
        guard let i = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        
        var items = rooms[i].editorItems
        items.move(fromOffsets: from, toOffset: to)
        let split = items.firstIndex { $0 == nil }!
        
        rooms[i].scenes = items[..<split].compactMap { $0 }
        rooms[i].disabledScenes = items[(split + 1)...].compactMap { $0 }
        saveOrder()
    }
    
    private func loadAliases() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: "hueAliases") as? [String: String] ?? [:]
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
    
    // All v2 calls go through here so `connection` always reflects the last response
    func send(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard bridgeState == .paired else { throw HueError.notPaired }

        var request = URLRequest(url: URL(string: "https://\(bridgeIP)/clip/v2/resource/\(path)")!)
        request.httpMethod = method
        request.setValue(username, forHTTPHeaderField: "hue-application-key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        var data = Data(), response = URLResponse()
        var code = 0
        // The bridge answers 429 when it is asked too much at once: wait and try again, twice at most
        for delay in Self.rateLimitDelays + [nil] {
            do {
                (data, response) = try await hueSession.data(for: request)
            } catch {
                connection = .unreachable
                Self.log.error("Request to \(path) failed: \(error)")
                throw HueError.unreachable(bridgeIP)
            }
            code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 429, let delay else { break }
            try? await Task.sleep(for: delay)
        }
        
        if code == 401 || code == 403 {
            connection = .unauthorized
            throw HueError.unauthorized
        }
        
        connection = .connected
        // The bridge can also report failures in the body of a 2xx response to a PUT
        let message = (method != "GET" || !(200..<300).contains(code))
            ? (try? JSONDecoder().decode(ErrorsResponse.self, from: data))?.errors.first?.description : nil
        if let message { throw HueError.rejected(message) }
        if code == 404 { throw HueError.notFound(path) }
        guard (200..<300).contains(code) else { throw HueError.rejected("HTTP \(code)") }
        return data
    }
    
    public func activateScene(scene: HueScene) async {
        do { try await recallScene(scene) } catch { Self.log.error("Activating scene failed: \(error)") }
    }
}
