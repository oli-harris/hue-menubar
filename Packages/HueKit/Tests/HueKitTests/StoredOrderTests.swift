import Testing
@testable import HueKit

private func room(_ id: String, scenes: [String] = [], disabled: [String] = []) -> HueRoom {
    HueRoom(id: id, groupedLightId: "", name: id, bridgeName: id,
            scenes: scenes.map { HueScene(id: $0, name: $0) },
            disabledScenes: disabled.map { HueScene(id: $0, name: $0) })
}

@Test func ordersRoomsAndScenes() {
    let order = StoredOrder(roomOrder: ["b", "a"], sceneOrder: ["a": ["s2", "s1"]])
    let result = order.apply(to: [room("a", scenes: ["s1", "s2"]), room("b"), room("c")])
    #expect(result.map(\.id) == ["b", "a", "c"])
    #expect(result[1].scenes.map(\.id) == ["s2", "s1"])
}

@Test func newScenesGoToBottomOfEnabled() {
    let order = StoredOrder(sceneOrder: ["a": ["s1", StoredOrder.disabledMarker, "s2"]])
    let result = order.apply(to: [room("a", scenes: ["s1", "s2", "new"])])
    #expect(result[0].scenes.map(\.id) == ["s1", "new"])
    #expect(result[0].disabledScenes.map(\.id) == ["s2"])
}
