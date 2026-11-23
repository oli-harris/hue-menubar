import Foundation

public struct HueXY: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// sRGB colour, components 0...1
public struct HueRGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    
    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
    
    // "#rgb" or "#rrggbb", the # optional, case-insensitive
    public init?(hex: String) {
        var digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 3 { digits = digits.flatMap { [$0, $0] }.map(String.init).joined() }
        guard digits.count == 6, let value = Int(digits, radix: 16), digits.allSatisfy(\.isHexDigit) else { return nil }
        self.init(r: Double(value >> 16) / 255, g: Double((value >> 8) & 0xFF) / 255, b: Double(value & 0xFF) / 255)
    }
    
    // xy in Hue's wide gamut (not clamped, the bridge maps it into the light's gamut) and brightness as a
    // percentage. Black has no chromaticity: it returns D65 white and brightness 0, meaning "off".
    public var xyBrightness: (xy: HueXY, brightness: Double) {
        func linear(_ c: Double) -> Double { c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92 }
        let (r, g, b) = (linear(r), linear(g), linear(b))
        let X = r * 0.664511 + g * 0.154324 + b * 0.162028
        let Y = r * 0.283881 + g * 0.668433 + b * 0.047685
        let Z = r * 0.000088 + g * 0.072310 + b * 0.986039
        let sum = X + Y + Z
        let brightness = max(self.r, self.g, self.b) * 100
        guard sum > 0 else { return (HueXY(x: 0.3127, y: 0.3290), 0) }
        return (HueXY(x: X / sum, y: Y / sum), brightness)
    }
}
