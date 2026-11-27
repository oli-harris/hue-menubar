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
    public let groupedLightId: String
    public internal(set) var name: String           // The local alias when set, else bridgeName
    public let bridgeName: String
    public internal(set) var scenes: [HueScene]     // Enabled, in menu order
    public internal(set) var disabledScenes: [HueScene] = []
    public internal(set) var activeSceneID: String?
    public internal(set) var lights: [HueLight] = []
    public internal(set) var isOn = false
    public internal(set) var brightness: Double?    // Percent
    public internal(set) var type: String? = nil                      // The bridge's room archetype, e.g. "bedroom"
    
    public var displayName: String { name == bridgeName ? name : "\(name) (\(bridgeName))" }
    
    // Scenes as edited in settings: enabled, nil as the divider, then disabled
    public var editorItems: [HueScene?] {
        scenes.map(Optional.some) + [nil] + disabledScenes.map(Optional.some)
    }
}

public struct HueLight: Identifiable, Codable {
    public let id: String
    public internal(set) var name: String           // The local alias when set, else bridgeName
    public let bridgeName: String
    public let type: String?                        // The bridge's light archetype, e.g. "floor_shade"
    public internal(set) var isOn: Bool
    public internal(set) var brightness: Double?    // Percent, nil when the light can't dim
    public internal(set) var xy: HueXY?             // Current colour, nil unless supportsColor
    public internal(set) var mirek: Int?            // Current colour temperature, nil in colour mode
    public internal(set) var colour: String?        // Approximate #rrggbb of what it shows, kept when off
    public let supportsColor: Bool
    public let supportsTemperature: Bool
    public let mirekMin: Int?                       // nil unless supportsTemperature
    public let mirekMax: Int?
    
    public var displayName: String { name == bridgeName ? name : "\(name) (\(bridgeName))" }
    
    // Current colour as a hex approximation, or the temperature in kelvin
    public var colourSummary: String? {
        if let mirek, mirek > 0, supportsTemperature { return "\(Int((1_000_000 / Double(mirek)).rounded()))K" }
        return xy.map { HueRGB(xy: $0).hex }
    }
    
    // What the bridge reports for every white-ambiance light, used for rooms and as a fallback
    static let defaultMirek = 153...500
    
    var mirekRange: ClosedRange<Int> {
        if let mirekMin, let mirekMax { return mirekMin...mirekMax }
        return Self.defaultMirek
    }
    
    init(_ api: LightAPI, aliases: [String: String]) {
        id = api.id
        bridgeName = api.metadata.name
        type = api.metadata.archetype
        name = aliases[api.id] ?? api.metadata.name
        isOn = api.on?.on ?? false
        brightness = api.dimming?.brightness
        xy = api.color?.xy
        mirek = api.color_temperature?.mirek
        colour = Self.colour(xy: xy, mirek: mirek)
        supportsColor = api.color != nil
        supportsTemperature = api.color_temperature != nil
        mirekMin = api.color_temperature?.mirek_schema?.mirek_minimum
        mirekMax = api.color_temperature?.mirek_schema?.mirek_maximum
    }
    
    // A mirek means colour temperature mode, as the bridge omits it in colour mode
    static func colour(xy: HueXY?, mirek: Int?) -> String? {
        mirek.flatMap(HueDisplayColour.hex(mirek:)) ?? xy.map(HueDisplayColour.hex(xy:))
    }
    
    // Mirrors what the bridge will do with a PUT, so state is current without a refresh
    mutating func apply(_ update: LightUpdate) {
        if let on = update.on?.on { isOn = on }
        if let b = update.dimming?.brightness, brightness != nil { brightness = b }
        if let c = update.color?.xy, supportsColor { xy = c }
        if let m = update.color_temperature?.mirek, supportsTemperature { mirek = min(max(m, mirekRange.lowerBound), mirekRange.upperBound); xy = nil }
        if update.color != nil { mirek = nil }
        colour = Self.colour(xy: xy, mirek: mirek)
    }
}

public struct HueScene: Identifiable, Codable {
    public let id: String
    public let name: String
    public internal(set) var colours: [String] = []     // One #rrggbb per light action, in the room's light order
}

// Scene actions to hex colours: the room's lights first in order, then any other targets. Actions that
// set no colour (just on/off or brightness) are skipped.
func sceneColours(_ actions: [SceneAPI.ActionEntry], lightOrder: [String]) -> [String] {
    let rank = { (a: SceneAPI.ActionEntry) in lightOrder.firstIndex(of: a.target.rid) ?? lightOrder.count }
    return actions.enumerated()
        .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
        .compactMap { _, a in a.action.color.map { HueDisplayColour.hex(xy: $0.xy) } ?? a.action.color_temperature.flatMap { HueDisplayColour.hex(mirek: $0.mirek) } }
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

// Builds the room list from decoded bridge resources. A light belongs to a room when its owner device
// is one of the room's device children; lights in no room come back as `unassigned`.
func assemble(rooms: [RoomAPI], scenes: [SceneAPI], lights: [LightAPI], groups: [GroupedLightAPI], aliases: [String: String]) -> (rooms: [HueRoom], unassigned: [HueLight]) {
    var placed = Set<String>()
    let built = rooms.map { room -> HueRoom in
        let devices = Set(room.children.filter { $0.rtype == "device" }.map(\.rid))
        let roomLights = lights.filter { devices.contains($0.owner.rid) }.map { HueLight($0, aliases: aliases) }
        placed.formUnion(roomLights.map(\.id))
        
        let groupedLightId = room.services.first { $0.rtype == "grouped_light" }?.rid ?? ""
        let group = groups.first { $0.id == groupedLightId }
        return HueRoom(
            id: room.id,
            groupedLightId: groupedLightId,
            name: aliases[room.id] ?? room.metadata.name,
            bridgeName: room.metadata.name,
            scenes: scenes
                .filter { $0.group.rid == room.id }
                .map { HueScene(id: $0.id, name: $0.metadata.name, colours: sceneColours($0.actions ?? [], lightOrder: roomLights.map(\.id))) },
            activeSceneID: scenes.first { $0.group.rid == room.id && $0.status?.active.map { $0 != "inactive" } == true }?.id,
            lights: roomLights,
            isOn: group?.on?.on ?? roomLights.contains { $0.isOn },
            brightness: group?.dimming?.brightness,
            type: room.metadata.archetype
        )
    }
    let unassigned = lights.filter { !placed.contains($0.id) }.map { HueLight($0, aliases: aliases) }
    return (built, unassigned)
}
