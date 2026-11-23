import Foundation

public enum HueSuggest {
    // Closest candidates by edit distance: at most 2 edits, or a third of the length for long names
    public static func closest(to input: String, in candidates: [String], limit: Int = 3) -> [String] {
        let input = input.lowercased()
        let maxDistance = max(2, input.count / 3)
        var seen = Set<String>()
        return candidates
            .compactMap { c -> (String, Int)? in
                let d = distance(input, c.lowercased())
                return d <= maxDistance && seen.insert(c).inserted ? (c, d) : nil
            }
            .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
            .prefix(limit).map(\.0)
    }
    
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var diagonal = row[0]
            row[0] = i
            for j in 1...max(b.count, 1) where !b.isEmpty {
                let above = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, diagonal + (a[i - 1] == b[j - 1] ? 0 : 1))
                diagonal = above
            }
        }
        return row[b.count]
    }
}

// Turns what the user typed into a light, room or all
public struct HueResolver {
    let rooms: [HueRoom]
    let lights: [HueLight]
    
    public init(rooms: [HueRoom], unassignedLights: [HueLight]) {
        self.rooms = rooms
        lights = rooms.flatMap(\.lights) + unassignedLights
    }
    
    public func room(containing light: HueLight) -> HueRoom? {
        rooms.first { $0.lights.contains { $0.id == light.id } }
    }
    
    // Exact id, else case-insensitive alias or bridge name; `room:` / `light:` restricts the kind
    public func resolve(_ query: String, allowAll: Bool = true) throws -> HueTarget {
        var query = query, wantRooms = true, wantLights = true
        if query.lowercased().hasPrefix("room:") { query.removeFirst(5); wantLights = false }
        else if query.lowercased().hasPrefix("light:") { query.removeFirst(6); wantRooms = false }
        else if allowAll, query.lowercased() == "all" { return .all }
        
        let q = query.lowercased()
        func matches(_ id: String, _ names: String...) -> Bool { id == query || names.contains { $0.lowercased() == q } }
        let hits: [(kind: String, name: String, id: String, target: HueTarget)] =
            (wantRooms ? rooms.filter { matches($0.id, $0.name, $0.bridgeName) }.map { ("room", $0.name, $0.id, .room($0)) } : [])
            + (wantLights ? lights.filter { matches($0.id, $0.name, $0.bridgeName) }.map { ("light", $0.name, $0.id, .light($0)) } : [])
        
        if hits.count == 1 { return hits[0].target }
        if hits.isEmpty {
            let names = (wantRooms ? rooms.flatMap { [$0.name, $0.bridgeName] } : []) + (wantLights ? lights.flatMap { [$0.name, $0.bridgeName] } : [])
            let close = HueSuggest.closest(to: query, in: names)
            throw HueError.invalid("Unknown \(allowAll ? "target" : "light or room") '\(query)'." + (close.isEmpty ? "" : " Did you mean: \(close.joined(separator: ", "))?"))
        }
        // Same-kind matches are listed by id, the only unambiguous handle
        let options = hits.map { hit in
            hits.filter { $0.kind == hit.kind }.count > 1 ? "\(hit.kind):\(hit.id)" : "\(hit.kind):\(hit.name)"
        }
        throw HueError.invalid("'\(query)' is ambiguous, it matches \(options.joined(separator: ", ")). Use one of those instead.")
    }
    
    // Among the room's scenes, enabled or not
    public func scene(_ query: String, in room: HueRoom) throws -> HueScene {
        let all = room.scenes + room.disabledScenes
        let hits = all.filter { $0.id == query || $0.name.lowercased() == query.lowercased() }
        if hits.count == 1 { return hits[0] }
        if hits.isEmpty {
            let close = HueSuggest.closest(to: query, in: all.map(\.name))
            throw HueError.invalid("Unknown scene '\(query)' in \(room.name)." + (close.isEmpty ? "" : " Did you mean: \(close.joined(separator: ", "))?"))
        }
        throw HueError.invalid("'\(query)' is ambiguous in \(room.name), it matches scene ids: \(hits.map(\.id).joined(separator: ", ")).")
    }
}
