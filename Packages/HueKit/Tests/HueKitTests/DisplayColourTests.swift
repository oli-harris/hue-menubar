import Foundation
import Testing
@testable import HueKit

@Test func kelvinToHex() {
    #expect(HueRGB.kelvin(2000).hex == "#ff890e")
    let daylight = HueRGB.kelvin(6500)
    #expect(daylight.r == 1 && daylight.g > 0.97 && daylight.b > 0.95)
    #expect(HueDisplayColour.hex(mirek: 500) == HueRGB.kelvin(2000).hex)
    #expect(HueDisplayColour.hex(mirek: 0) == nil)
}

@Test func xyToHex() {
    #expect(HueDisplayColour.hex(xy: HueRGB(hex: "f00")!.xyBrightness.xy) == "#ff0000")
    let white = HueRGB(hex: HueDisplayColour.hex(xy: HueXY(x: 0.3227, y: 0.3290)))!
    #expect(white.r > 0.97 && white.g > 0.97 && white.b > 0.97)
}

@Test func lightColourFollowsMode() throws {
    func decode(_ json: String) throws -> HueLight {
        HueLight(try JSONDecoder().decode(LightAPI.self, from: Data(json.utf8)), aliases: [:])
    }
    let ct = try decode(#"{"id":"a","owner":{"rid":"d","rtype":"device"},"metadata":{"name":"A"},"on":{"on":false},"color_temperature":{"mirek":500}}"#)
    #expect(ct.colour == "#ff890e")      // Off lights keep their last colour
    let xy = try decode(#"{"id":"b","owner":{"rid":"d","rtype":"device"},"metadata":{"name":"B"},"color":{"xy":{"x":0.7006,"y":0.2993}}}"#)
    #expect(xy.colour == "#ff0000")
    var changed = xy
    changed.apply(LightUpdate(color_temperature: .init(mirek: 500)))   // No temperature support, so unchanged
    #expect(changed.colour == "#ff0000")
}

@Test func sceneColours() throws {
    let actions = try JSONDecoder().decode(ScenesResponse.self, from: Data("""
    {"data":[{"id":"s","metadata":{"name":"S"},"group":{"rid":"r","rtype":"room"},"actions":[
      {"target":{"rid":"l2","rtype":"light"},"action":{"color_temperature":{"mirek":500}}},
      {"target":{"rid":"l1","rtype":"light"},"action":{"color":{"xy":{"x":0.7006,"y":0.2993}}}},
      {"target":{"rid":"l3","rtype":"light"},"action":{"on":{"on":true},"dimming":{"brightness":50}}},
      {"target":{"rid":"l9","rtype":"light"},"action":{"color":{"xy":{"x":0.7006,"y":0.2993}}}}]}]}
    """.utf8)).data[0].actions ?? []
    #expect(HueKit.sceneColours(actions, lightOrder: ["l1", "l2", "l3"]) == ["#ff0000", "#ff890e", "#ff0000"])
    #expect(HueKit.sceneColours([], lightOrder: []) == [])
}
