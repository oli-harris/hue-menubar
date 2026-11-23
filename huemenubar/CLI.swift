import Foundation
import HueKit

enum CLI {
    static let usage: [(command: String, line: String, about: String)] = [
        ("status", "status [--json]", "Show the bridge connection and how many lights are on"),
        ("rooms", "rooms [--json]", "List rooms with state, active scene and scenes"),
        ("lights", "lights [--json]", "List every light, including ones in no room"),
        ("alias", "alias <light|room> <new name> | alias <light|room> --clear", "Give a light or room a local nickname"),
        ("colours", "colours", "List the CSS colour names and white keywords"),
        ("colour", "colour <light|room|all> <value> [brightness%]", "Set a colour: #rrggbb, #rgb, a CSS name, 2700K or a white keyword"),
        ("on", "on <light|room|all> [brightness%]", "Turn on, optionally at a brightness"),
        ("off", "off <light|room|all>", "Turn off"),
        ("brightness", "brightness <light|room|all> <0-100>[%]", "Set brightness (0 turns off)"),
        ("temp", "temp <light|room|all> <kelvin[K]|candle|warm|neutral|cool|daylight>", "Set the colour temperature"),
        ("scene", "scene <light|room> <scene>", "Recall a scene in a room, or only a light's part of it"),
        ("help", "help", "Show this help"),
    ]
    static let commands = Set(usage.map(\.command))
    
    static let help = """
        Usage: hue <command> [arguments]
        
        \(usage.map { "  hue \($0.line)\n      \($0.about)" }.joined(separator: "\n"))
        
        Targets are matched by id or name (case-insensitive, aliases included). Quote names with spaces.
        Prefix with room: or light: when a name is both, e.g. hue off room:Lounge. "all" means every light.
        Mistyped names are never corrected, only suggested. Add --json to status, rooms and lights for JSON.
        Exit codes: 0 ok, 1 failed, 2 not paired, 64 usage error.
        """
    
    private struct Status: Encodable {
        let paired: Bool
        let bridgeIP: String?
        let bridgeID: String?
        let connection: String
        let rooms: Int
        let lights: Int
        let lightsOn: Int
    }
    
    private struct LightsOutput: Encodable {
        let rooms: [HueRoom]
        let unassigned: [HueLight]
    }
    
    private struct Failure: Error {
        let message: String
        let code: Int32
    }
    
    @MainActor
    static func run(_ arguments: [String]) async -> Int32 {
        var args = arguments
        let command = args.isEmpty ? "help" : args.removeFirst()
        if ["help", "-h", "--help"].contains(command) { print(help); return 0 }
        guard let entry = usage.first(where: { $0.command == command }) else {
            return fail("Unknown command '\(command)'.\n\(help)", 64)
        }
        
        let json = args.contains("--json")
        let clear = args.contains("--clear")
        args.removeAll { $0 == "--json" || $0 == "--clear" }
        
        defer { UserDefaults.standard.synchronize() }
        do {
            if command == "colours" { colours(); return 0 }
            try await connect(command: command, json: json)
            let client = HueClient.shared
            let resolver = HueResolver(rooms: client.rooms, unassignedLights: client.unassignedLights)
            
            func need(_ count: ClosedRange<Int>) throws {
                if !count.contains(args.count) { throw Failure(message: "Usage: hue \(entry.line)", code: 64) }
            }
            func target(allowAll: Bool = true) throws -> HueTarget { try resolver.resolve(args[0], allowAll: allowAll) }
            func percent(_ i: Int) throws -> Double? { try args.count > i ? HueColors.parsePercent(args[i]) : nil }
            
            switch command {
            case "status":
                try need(0...0)
                let lights = client.rooms.flatMap(\.lights) + client.unassignedLights
                let info = Status(paired: true, bridgeIP: client.bridgeIP, bridgeID: client.bridgeID, connection: client.connection.rawValue,
                                  rooms: client.rooms.count, lights: lights.count, lightsOn: lights.filter(\.isOn).count)
                if json { printJSON(info) } else {
                    print("Bridge:      \(info.bridgeIP ?? "") (\(info.bridgeID ?? ""))\nConnection:  \(info.connection)\nRooms:       \(info.rooms)\nLights:      \(info.lights), \(info.lightsOn) on")
                }
            case "rooms":
                try need(0...0)
                if json { printJSON(client.rooms) } else {
                    table(["ROOM", "STATE", "SCENE", "LIGHTS", "SCENES"], client.rooms.map { room in
                        [room.displayName, state(on: room.isOn, brightness: room.brightness),
                         (room.scenes + room.disabledScenes).first { $0.id == room.activeSceneID }?.name ?? "-",
                         "\(room.lights.count)", (room.scenes + room.disabledScenes).map(\.name).joined(separator: ", ")]
                    })
                }
            case "lights":
                try need(0...0)
                if json { printJSON(LightsOutput(rooms: client.rooms, unassigned: client.unassignedLights)) } else {
                    let rows = client.rooms.flatMap { room in room.lights.map { ($0, room.name) } } + client.unassignedLights.map { ($0, "-") }
                    table(["LIGHT", "ROOM", "STATE", "CAPABILITIES", "COLOUR"], rows.map { light, room in
                        [light.displayName, room, state(on: light.isOn, brightness: light.brightness),
                         [light.brightness != nil ? "dim" : nil, light.supportsColor ? "colour" : nil, light.supportsTemperature ? "temp" : nil]
                            .compactMap { $0 }.joined(separator: ","),
                         light.colourSummary ?? "-"]
                    })
                }
            case "alias":
                try need(clear ? 1...1 : 2...2)
                switch try target(allowAll: false) {
                case .light(let l): client.setAlias(clear ? nil : args[1], for: l.id)
                case .room(let r): client.setAlias(clear ? nil : args[1], for: r.id)
                case .all: break
                }
                print(clear ? "Alias cleared" : "Alias set to \(args[1])")
            case "on":
                try need(1...2)
                try await client.set(try target(), on: true, brightness: try percent(1))
                print("On")
            case "off":
                try need(1...1)
                try await client.set(try target(), on: false)
                print("Off")
            case "brightness":
                try need(2...2)
                try await client.set(try target(), brightness: try percent(1))
                print("Brightness \(args[1])")
            case "temp":
                try need(2...2)
                try await client.set(try target(), kelvin: try HueColors.parseKelvin(args[1]))
                print("Temperature \(args[1])")
            case "colour":
                try need(2...3)
                let t = try target()
                let brightness = try percent(2)
                switch try HueColors.parse(args[1]) {
                case .kelvin(let k): try await client.set(t, brightness: brightness, kelvin: k)
                case .rgb(let rgb):
                    let (xy, fromColour) = rgb.xyBrightness
                    try await client.set(t, brightness: brightness ?? fromColour, color: xy)
                }
                print("Colour \(args[1])")
            case "scene":
                try need(2...2)
                switch try target(allowAll: false) {
                case .room(let room):
                    try await client.recallScene(try resolver.scene(args[1], in: room))
                case .light(let light):
                    guard let room = resolver.room(containing: light) else { throw HueError.invalid("\(light.name) isn't in a room, so it has no scenes") }
                    try await client.applyScene(try resolver.scene(args[1], in: room), to: light)
                case .all: break
                }
                print("Scene \(args[1])")
            default: break
            }
            return 0
        } catch let failure as Failure {
            return fail(failure.message, failure.code)
        } catch {
            return fail(error.localizedDescription, 1)
        }
    }
    
    // Everything except help and colours needs a paired bridge and fresh state
    @MainActor
    private static func connect(command: String, json: Bool) async throws {
        let client = HueClient.shared
        guard client.bridgeState == .paired else {
            if command == "status" && json { printJSON(Status(paired: false, bridgeIP: nil, bridgeID: nil, connection: "unpaired", rooms: 0, lights: 0, lightsOn: 0)) }
            throw Failure(message: "Not paired — open Hue Menubar to pair", code: 2)
        }
        await client.refresh()
        if !client.fetchStatus.isEmpty { throw Failure(message: client.fetchStatus, code: 1) }
    }
    
    private static func colours() {
        let tty = isatty(STDOUT_FILENO) != 0
        let rows = HueColors.css.map { ($0.name, "#" + $0.hex, HueRGB(hex: $0.hex)) } + HueColors.whites.map { ($0.name, "\($0.kelvin)K", nil) }
        let width = rows.map(\.0.count).max() ?? 0
        for (name, value, rgb) in rows {
            // Escape codes would throw off padding, so pad separately; white keywords get no swatch (no exact RGB)
            let swatch = tty ? rgb.map { "\u{1B}[48;2;\(Int($0.r * 255));\(Int($0.g * 255));\(Int($0.b * 255))m  \u{1B}[0m " } ?? "   " : ""
            print(swatch + name + String(repeating: " ", count: width - name.count + 2) + value)
        }
    }
    
    private static func state(on: Bool, brightness: Double?) -> String {
        on ? "on" + (brightness.map { " \(Int($0.rounded()))%" } ?? "") : "off"
    }
    
    private static func table(_ header: [String], _ rows: [[String]]) {
        let all = [header] + rows
        let widths = header.indices.map { i in all.map { $0[i].count }.max() ?? 0 }
        for row in all {
            print(row.enumerated().map { $1.padding(toLength: widths[$0], withPad: " ", startingAt: 0) }.joined(separator: "  ")
                .trimmingCharacters(in: .whitespaces))
        }
    }
    
    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: (try? encoder.encode(value)) ?? Data(), as: UTF8.self))
    }
    
    private static func fail(_ message: String, _ code: Int32) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return code
    }
}
