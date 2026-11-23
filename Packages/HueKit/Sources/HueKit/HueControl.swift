import Foundation

public enum HueTarget {
    case light(HueLight)
    case room(HueRoom)
    case all        // Every light, via the bridge_home grouped_light
}

public enum HueError: LocalizedError {
    case notPaired
    case unreachable(String)
    case unauthorized
    case unsupported(String)
    case rejected(String)       // The bridge's own error description
    case notFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .notPaired: "No bridge paired"
        case .unreachable(let ip): "Can't reach the bridge at \(ip)"
        case .unauthorized: "The bridge rejected the stored pairing, pair again"
        case .unsupported(let what): "\(what)"
        case .rejected(let message): "The bridge rejected the request: \(message)"
        case .notFound(let what): "Not found: \(what)"
        }
    }
}

extension LightUpdate {
    // Setting brightness, colour or temperature implies on; brightness 0 means off and sends nothing else.
    // `light` is nil for rooms and the whole home, which can't be checked per feature.
    static func make(on: Bool?, brightness: Double?, color: HueXY?, kelvin: Int?, light: HueLight?) throws -> LightUpdate {
        if let light {
            if color != nil, !light.supportsColor { throw HueError.unsupported("\(light.name) doesn't support colour") }
            if kelvin != nil, !light.supportsTemperature { throw HueError.unsupported("\(light.name) doesn't support colour temperature") }
        }
        if let kelvin, kelvin <= 0 { throw HueError.unsupported("Colour temperature must be a positive number of kelvin") }
        
        if brightness == 0 { return LightUpdate(on: .init(on: false)) }
        
        let adjusting = brightness != nil || color != nil || kelvin != nil
        var update = LightUpdate()
        if let isOn = on ?? (adjusting ? true : nil) { update.on = .init(on: isOn) }
        if let brightness { update.dimming = .init(brightness: min(max(brightness, 0), 100)) }
        if let color { update.color = .init(xy: color) }
        if let kelvin {
            let range = light?.mirekRange ?? HueLight.defaultMirek
            update.color_temperature = .init(mirek: min(max(Int((1_000_000 / Double(kelvin)).rounded()), range.lowerBound), range.upperBound))
        }
        return update
    }
}

extension HueClient {
    // One PUT, so colour and brightness change together without flicker
    public func set(_ target: HueTarget, on: Bool? = nil, brightness: Double? = nil, color: HueXY? = nil, kelvin: Int? = nil) async throws {
        let light: HueLight?
        let path: String
        switch target {
        case .light(let l): light = l; path = "light/\(l.id)"
        case .room(let r): light = nil; path = "grouped_light/\(r.groupedLightId)"
        case .all: light = nil; path = "grouped_light/\(try await allGroupedLightID())"
        }
        
        let update = try LightUpdate.make(on: on, brightness: brightness, color: color, kelvin: kelvin, light: light)
        _ = try await send(path, method: "PUT", body: try JSONEncoder().encode(update))
        apply(update, to: target)
    }
    
    // Applies only this light's action from the scene, leaving the rest of the room alone
    public func applyScene(_ scene: HueScene, to light: HueLight) async throws {
        guard let action = sceneActions[scene.id]?.first(where: { $0.target.rid == light.id })?.action else {
            throw HueError.notFound("\(scene.name) has no action for \(light.name)")
        }
        _ = try await send("light/\(light.id)", method: "PUT", body: try JSONEncoder().encode(action))
        apply(action, to: .light(light))
    }
    
    public func turnOffRoom(room: HueRoom) async {
        let i = rooms.firstIndex(where: { $0.id == room.id })
        let previous = i.flatMap { rooms[$0].activeSceneID }
        if let i { rooms[i].activeSceneID = nil }
        do {
            try await set(.room(room), on: false)
        } catch {
            Self.log.error("Turning off room failed: \(error)")
            if let i { rooms[i].activeSceneID = previous }
        }
    }
    
    // Nicknames are local only; nil or empty removes
    public func setAlias(_ name: String?, for id: String) {
        var aliases = UserDefaults.standard.dictionary(forKey: "hueAliases") as? [String: String] ?? [:]
        aliases[id] = name.flatMap { $0.isEmpty ? nil : $0 }
        UserDefaults.standard.set(aliases, forKey: "hueAliases")
        
        for r in rooms.indices {
            if rooms[r].id == id { rooms[r].name = aliases[id] ?? rooms[r].bridgeName }
            for l in rooms[r].lights.indices where rooms[r].lights[l].id == id {
                rooms[r].lights[l].name = aliases[id] ?? rooms[r].lights[l].bridgeName
            }
        }
        for l in unassignedLights.indices where unassignedLights[l].id == id {
            unassignedLights[l].name = aliases[id] ?? unassignedLights[l].bridgeName
        }
    }
    
    func allGroupedLightID() async throws -> String {
        if let allGroupedLightId { return allGroupedLightId }
        let home = try JSONDecoder().decode(BridgeHomeResponse.self, from: try await send("bridge_home"))
        guard let id = home.data.first?.services.first(where: { $0.rtype == "grouped_light" })?.rid else {
            throw HueError.notFound("bridge_home grouped light")
        }
        allGroupedLightId = id
        return id
    }
    
    private func apply(_ update: LightUpdate, to target: HueTarget) {
        func group(_ room: inout HueRoom) {
            if let on = update.on?.on { room.isOn = on }
            if let b = update.dimming?.brightness { room.brightness = b }
            for l in room.lights.indices { room.lights[l].apply(update) }
        }
        
        switch target {
        case .all:
            for r in rooms.indices { group(&rooms[r]) }
            for l in unassignedLights.indices { unassignedLights[l].apply(update) }
        case .room(let room):
            if let r = rooms.firstIndex(where: { $0.id == room.id }) { group(&rooms[r]) }
        case .light(let light):
            for r in rooms.indices {
                guard let l = rooms[r].lights.firstIndex(where: { $0.id == light.id }) else { continue }
                rooms[r].lights[l].apply(update)
                rooms[r].isOn = rooms[r].lights.contains { $0.isOn }
            }
            if let l = unassignedLights.firstIndex(where: { $0.id == light.id }) { unassignedLights[l].apply(update) }
        }
    }
}
