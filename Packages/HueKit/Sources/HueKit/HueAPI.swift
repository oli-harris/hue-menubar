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
    let children: [Service]     // Devices (rtype "device") in the room
    
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
    let actions: [ActionEntry]?
    
    struct ActionEntry: Decodable {
        let target: Ref
        let action: LightUpdate     // gradient and effects are ignored
    }
    
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

struct Ref: Decodable {
    let rid: String
    let rtype: String
}

struct BridgeHomeResponse: Decodable {
    let data: [BridgeHomeAPI]
    
    struct BridgeHomeAPI: Decodable {
        let services: [RoomAPI.Service]
    }
}

struct GroupedLightsResponse: Decodable {
    let data: [GroupedLightAPI]
}

struct GroupedLightAPI: Decodable {
    let id: String
    let on: LightUpdate.On?
    let dimming: LightUpdate.Dimming?
}

struct LightsResponse: Decodable {
    let data: [LightAPI]
}

struct LightAPI: Decodable {
    let id: String
    let owner: Ref
    let metadata: RoomAPI.Metadata
    let on: LightUpdate.On?
    let dimming: LightUpdate.Dimming?
    let color: LightUpdate.Color?                // Only on colour lights
    let color_temperature: Temperature?          // Only on white-ambiance capable lights
    
    struct Temperature: Decodable {
        let mirek: Int?                          // null while the light is in colour mode
        let mirek_schema: Schema?
    }
    
    struct Schema: Decodable {
        let mirek_minimum: Int
        let mirek_maximum: Int
    }
}

// Body of a light or grouped_light PUT; also the shape of a scene's per-light action
struct LightUpdate: Codable {
    var on: On?
    var dimming: Dimming?
    var color: Color?
    var color_temperature: Temperature?
    
    struct On: Codable { let on: Bool }
    struct Dimming: Codable { let brightness: Double }
    struct Color: Codable { let xy: HueXY }
    struct Temperature: Codable { let mirek: Int }
}

// Error envelope of v2 responses
struct ErrorsResponse: Decodable {
    let errors: [Item]
    
    struct Item: Decodable { let description: String }
}
