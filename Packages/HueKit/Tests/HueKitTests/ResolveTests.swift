import Foundation
import Testing
@testable import HueKit

private func light(_ id: String, _ name: String, alias: String? = nil) -> HueLight {
    let json = #"{"id":"\#(id)","owner":{"rid":"d\#(id)","rtype":"device"},"metadata":{"name":"\#(name)"},"on":{"on":true}}"#
    return HueLight(try! JSONDecoder().decode(LightAPI.self, from: Data(json.utf8)), aliases: alias.map { [id: $0] } ?? [:])
}

private func room(_ id: String, _ name: String, lights: [HueLight] = [], scenes: [String] = []) -> HueRoom {
    HueRoom(id: id, groupedLightId: "g" + id, name: name, bridgeName: name,
            scenes: scenes.map { HueScene(id: "s" + $0, name: $0) }, lights: lights)
}

private var resolver: HueResolver { HueResolver(
    rooms: [room("r1", "Lounge", lights: [light("l1", "Lamp", alias: "Reading"), light("l2", "Lounge")], scenes: ["Relax", "Energise"]),
            room("r2", "Office", lights: [light("l3", "Lamp")])],
    unassignedLights: [light("l4", "Porch")]) }

private func message(_ q: String, allowAll: Bool = true) -> String? {
    do { _ = try resolver.resolve(q, allowAll: allowAll); return nil } catch { return error.localizedDescription }
}

@Test func resolvesByIdNameAliasAndAll() throws {
    guard case .light(let a) = try resolver.resolve("l3"), a.id == "l3" else { Issue.record("id"); return }
    guard case .light(let b) = try resolver.resolve("READING"), b.id == "l1" else { Issue.record("alias"); return }
    guard case .room(let d) = try resolver.resolve("office"), d.id == "r2" else { Issue.record("room"); return }
    guard case .all = try resolver.resolve("All") else { Issue.record("all"); return }
    #expect(message("all", allowAll: false)?.contains("Unknown") == true)
}

@Test func reportsAmbiguity() throws {
    // Same name on a room and a light, and on two lights
    #expect(message("lounge")?.contains("room:Lounge") == true && message("lounge")?.contains("light:Lounge") == true)
    // The aliased light still answers to its bridge name, so "lamp" is two lights and needs ids
    #expect(message("lamp")?.contains("light:l1, light:l3") == true)
    guard case .room(let r) = try resolver.resolve("room:lounge") else { Issue.record("prefix"); return }
    #expect(r.id == "r1")
    guard case .light(let l) = try resolver.resolve("light:lounge") else { Issue.record("prefix"); return }
    #expect(l.id == "l2")
}

@Test func suggestsClosest() {
    #expect(message("Offcie")?.contains("Did you mean: Office") == true)
    #expect(message("zzzzzz")?.contains("Did you mean") == false)
    #expect(HueSuggest.closest(to: "tomatoe", in: HueColors.css.map(\.name)) == ["tomato"])
    #expect(HueSuggest.closest(to: "lightgoldenrodyelow", in: HueColors.css.map(\.name)).first == "lightgoldenrodyellow")
    #expect((try? HueColors.parse("tomatoe")) == nil)
}

@Test func resolvesScenes() throws {
    let lounge = try #require(resolver.rooms.first)
    #expect(try resolver.scene("relax", in: lounge).id == "sRelax")
    #expect(throws: HueError.self) { try resolver.scene("relx ", in: lounge) }
    #expect(resolver.room(containing: lounge.lights[0])?.id == "r1")
    #expect(resolver.room(containing: light("l4", "Porch")) == nil)
}

@Test func parsesColourValues() throws {
    #expect(HueColors.css.count == 148)
    #expect(try HueColors.parse("#f00") == .rgb(HueRGB(r: 1, g: 0, b: 0)))
    #expect(try HueColors.parse("TOMATO") == .rgb(HueRGB(hex: "ff6347")!))
    #expect(try HueColors.parse("2700k") == .kelvin(2700))
    #expect(try HueColors.parse("Warm") == .kelvin(2700))
    #expect(try HueColors.parse("ff0000") == .rgb(HueRGB(r: 1, g: 0, b: 0)))
    for bad in ["#12345", "#ggg", "0K", "", "banana"] { #expect(throws: HueError.self) { try HueColors.parse(bad) } }
    #expect(try HueColors.parseKelvin("4000") == 4000 && HueColors.parseKelvin("daylight") == 6500)
    #expect(try HueColors.parsePercent("40%") == 40)
    #expect(throws: HueError.self) { try HueColors.parsePercent("101") }
}

@Test func approximatesHexFromXY() {
    let red = HueRGB(hex: "#ff0000")!.xyBrightness.xy
    #expect(HueRGB(xy: red).hex == "#ff0000")
}
