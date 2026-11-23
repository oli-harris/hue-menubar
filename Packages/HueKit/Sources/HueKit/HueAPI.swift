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
