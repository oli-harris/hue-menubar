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

extension HueRGB {
    // Approximate inverse of xyBrightness at full brightness, for display
    public init(xy: HueXY) {
        let y = max(xy.y, 0.0001)
        let (X, Y, Z) = (xy.x / y, 1.0, (1 - xy.x - xy.y) / y)
        var c = [X * 1.656492 - Y * 0.354851 - Z * 0.255038,
                 -X * 0.707196 + Y * 1.655397 + Z * 0.036152,
                 X * 0.051713 - Y * 0.121364 + Z * 1.011530].map { max($0, 0) }
        let peak = c.max() ?? 1
        if peak > 0 { c = c.map { $0 / peak } }
        c = c.map { $0 <= 0.0031308 ? 12.92 * $0 : 1.055 * pow($0, 1 / 2.4) - 0.055 }
        self.init(r: c[0], g: c[1], b: c[2])
    }
    
    public var hex: String {
        String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

extension HueRGB {
    // Tanner Helland's approximation of a black body, good for roughly 1000-40000K
    public static func kelvin(_ kelvin: Double) -> HueRGB {
        let t = min(max(kelvin, 1000), 40000) / 100
        let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307
        func c(_ v: Double) -> Double { min(max(v, 0), 255) / 255 }
        return HueRGB(r: c(r), g: c(g), b: c(b))
    }
}

// The single place a bridge colour becomes a display hex, so text and JSON output agree
enum HueDisplayColour {
    static func hex(mirek: Int) -> String? {
        mirek > 0 ? HueRGB.kelvin(1_000_000 / Double(mirek)).hex : nil
    }
    
    static func hex(xy: HueXY) -> String { HueRGB(xy: xy).hex }
}
