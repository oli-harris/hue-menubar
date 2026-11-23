import Foundation

// Setup progress: what we have stored
public enum HueBridgeState: String {
    case noBridge
    case bridgeFound
    case paired
}

// Reachability of a paired bridge, from the last request made to it
public enum HueConnection: String {
    case checking
    case connected
    case unreachable
    case unauthorized
}

public struct HueRoom: Identifiable, Codable {
    public let id: String
    let groupedLightId: String
    public let roomName: String
    public internal(set) var scenes: [HueScene]                  // Enabled, in menu order
    public internal(set) var disabledScenes: [HueScene] = []
    public internal(set) var activeSceneID: String?
    
    // Scenes as edited in settings: enabled, nil as the divider, then disabled
    public var editorItems: [HueScene?] {
        scenes.map(Optional.some) + [nil] + disabledScenes.map(Optional.some)
    }
}

public struct HueScene: Identifiable, Codable {
    public let id: String
    public let name: String
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
