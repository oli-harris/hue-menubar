import Foundation

struct HueScene {
    var name: String
    var number: Int
    var selected: Bool = false
}

func getScenes() -> [HueScene] {
    return [HueScene(name:"On", number:0, selected:true), HueScene(name: "Off", number: 1)]
}

func setScene(id: Int) {
    print(id)
}
