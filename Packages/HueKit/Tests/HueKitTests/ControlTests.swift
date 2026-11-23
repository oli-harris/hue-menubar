import Foundation
import Testing
@testable import HueKit

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

@Test func parsesHex() {
    #expect(HueRGB(hex: "#FF8000") == HueRGB(r: 1, g: 128.0 / 255, b: 0))
    #expect(HueRGB(hex: "f00") == HueRGB(r: 1, g: 0, b: 0))
    #expect(HueRGB(hex: "#0aF") == HueRGB(hex: "00aaff"))
    for bad in ["", "#", "12", "#12345", "ggg", "#1234567", "+12345"] { #expect(HueRGB(hex: bad) == nil) }
}

@Test func convertsToXY() {
    let white = HueRGB(r: 1, g: 1, b: 1).xyBrightness
    #expect(abs(white.xy.x - 0.3227) < 0.001 && abs(white.xy.y - 0.3290) < 0.001)
    #expect(white.brightness == 100)
    let red = HueRGB(hex: "#f00")!.xyBrightness
    #expect(abs(red.xy.x - 0.70) < 0.01 && abs(red.xy.y - 0.30) < 0.01)
    #expect(HueRGB(hex: "#000")!.xyBrightness.brightness == 0)
}

private let ambiance = try! decode(LightAPI.self, """
{"id":"l1","owner":{"rid":"d1","rtype":"device"},"metadata":{"name":"Desk"},"on":{"on":true},
 "dimming":{"brightness":50.0},"color_temperature":{"mirek":300,"mirek_schema":{"mirek_minimum":153,"mirek_maximum":454}}}
""")

@Test func lightUpdateRules() throws {
    let light = HueLight(ambiance, aliases: [:])
    // 1_000_000 / 2000 = 500, clamped to this light's 454
    #expect(try LightUpdate.make(on: nil, brightness: nil, color: nil, kelvin: 2000, light: light).color_temperature?.mirek == 454)
    #expect(try LightUpdate.make(on: nil, brightness: nil, color: nil, kelvin: 6500, light: light).color_temperature?.mirek == 154)
    #expect(try LightUpdate.make(on: nil, brightness: nil, color: nil, kelvin: 20000, light: nil).color_temperature?.mirek == 153)
    #expect(try LightUpdate.make(on: nil, brightness: 40, color: nil, kelvin: nil, light: light).on?.on == true)
    let off = try LightUpdate.make(on: nil, brightness: 0, color: HueXY(x: 0.3, y: 0.3), kelvin: nil, light: nil)
    #expect(off.on?.on == false && off.dimming == nil && off.color == nil)
    #expect(throws: HueError.self) { try LightUpdate.make(on: nil, brightness: nil, color: HueXY(x: 0.3, y: 0.3), kelvin: nil, light: light) }
    let colourOnly = try decode(LightAPI.self, #"{"id":"l2","owner":{"rid":"d2","rtype":"device"},"metadata":{"name":"Strip"},"color":{"xy":{"x":0.4,"y":0.4}}}"#)
    #expect(throws: HueError.self) { try LightUpdate.make(on: nil, brightness: nil, color: nil, kelvin: 3000, light: HueLight(colourOnly, aliases: [:])) }
}

@Test func assemblesRoomsAndAliases() throws {
    let rooms = try decode(RoomsResponse.self, """
    {"data":[{"id":"r1","metadata":{"name":"Office"},"services":[{"rid":"g1","rtype":"grouped_light"}],
              "children":[{"rid":"d1","rtype":"device"}]}]}
    """).data
    let lights = try decode(LightsResponse.self, """
    {"data":[{"id":"l1","owner":{"rid":"d1","rtype":"device"},"metadata":{"name":"Desk"},"on":{"on":true}},
             {"id":"l2","owner":{"rid":"d9","rtype":"device"},"metadata":{"name":"Hall"},"on":{"on":false}}]}
    """).data
    let groups = try decode(GroupedLightsResponse.self, #"{"data":[{"id":"g1","on":{"on":true},"dimming":{"brightness":80.0}}]}"#).data
    let result = assemble(rooms: rooms, scenes: [], lights: lights, groups: groups, aliases: ["r1": "Study", "l1": "Lamp"])
    #expect(result.rooms[0].name == "Study" && result.rooms[0].bridgeName == "Office")
    #expect(result.rooms[0].lights.map(\.name) == ["Lamp"] && result.rooms[0].lights[0].bridgeName == "Desk")
    #expect(result.rooms[0].isOn && result.rooms[0].brightness == 80 && result.rooms[0].groupedLightId == "g1")
    #expect(result.unassigned.map(\.id) == ["l2"])
}

@Test func decodesSceneActions() throws {
    let scene = try decode(ScenesResponse.self, """
    {"data":[{"id":"s1","metadata":{"name":"Relax"},"group":{"rid":"r1","rtype":"room"},"actions":[
      {"target":{"rid":"l1","rtype":"light"},"action":{"on":{"on":true},"dimming":{"brightness":30.0},"color_temperature":{"mirek":400},"effects_v2":{}}},
      {"target":{"rid":"l2","rtype":"light"},"action":{"color":{"xy":{"x":0.5,"y":0.4}}}}]}]}
    """).data[0]
    let action = scene.actions?.first { $0.target.rid == "l1" }?.action
    #expect(action?.dimming?.brightness == 30 && action?.color_temperature?.mirek == 400 && action?.color == nil)
    #expect(scene.actions?.first { $0.target.rid == "l3" } == nil)
    #expect(scene.actions?.first { $0.target.rid == "l2" }?.action.color?.xy == HueXY(x: 0.5, y: 0.4))
}
