import SwiftUI

/// A SwiftUI `Shape` that renders an Android/SVG vector `pathData` string, scaled uniformly to
/// fit its rect. Supports M/L/H/V/C/Q/Z (absolute + relative + implicit repeats) — the command
/// set used by the bundled logos. Vector-perfect and tintable, so the credit-footer logos need
/// no raster assets and adapt to light/dark.
struct VectorPathShape: Shape {
    let pathData: String
    let viewport: CGSize
    /// A leading translate applied to the raw coordinates (Android `<group android:translate…>`).
    var translate: CGPoint = .zero

    func path(in rect: CGRect) -> Path {
        var raw = Path()
        var parser = PathDataParser(pathData)
        parser.build(into: &raw)

        // Fit the viewport into `rect`, uniform scale, centered.
        let scale = min(rect.width / viewport.width, rect.height / viewport.height)
        let drawW = viewport.width * scale
        let drawH = viewport.height * scale
        let dx = rect.minX + (rect.width - drawW) / 2
        let dy = rect.minY + (rect.height - drawH) / 2

        // Point order: raw → +translate → ×scale → +center offset.
        var transform = CGAffineTransform(translationX: dx, y: dy)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: translate.x, y: translate.y)
        return raw.applying(transform)
    }
}

/// Minimal SVG path-data parser: handles the M/L/H/V/C/Q/Z command set (upper = absolute,
/// lower = relative), implicit command repetition, and comma/whitespace/sign separators.
private struct PathDataParser {
    private let chars: [Character]
    private var i = 0

    init(_ string: String) { chars = Array(string) }

    mutating func build(into path: inout Path) {
        var command: Character = " "
        var current = CGPoint.zero
        var start = CGPoint.zero
        var guardCounter = 0
        let guardMax = chars.count * 4 + 16   // safety net against malformed input

        while i < chars.count {
            guardCounter += 1
            if guardCounter > guardMax { break }
            skipSeparators()
            guard i < chars.count else { break }

            if chars[i].isLetter {
                command = chars[i]
                i += 1
            }

            switch command {
            case "M", "m":
                let p = readPoint(base: command == "m" ? current : nil)
                path.move(to: p); current = p; start = p
                command = command == "m" ? "l" : "L"   // extra coords after M are implicit lineto
            case "L", "l":
                let p = readPoint(base: command == "l" ? current : nil)
                path.addLine(to: p); current = p
            case "H", "h":
                let x = readNumber() + (command == "h" ? Double(current.x) : 0)
                let p = CGPoint(x: x, y: Double(current.y)); path.addLine(to: p); current = p
            case "V", "v":
                let y = readNumber() + (command == "v" ? Double(current.y) : 0)
                let p = CGPoint(x: Double(current.x), y: y); path.addLine(to: p); current = p
            case "C", "c":
                let base: CGPoint? = command == "c" ? current : nil
                let c1 = readPoint(base: base)
                let c2 = readPoint(base: base)
                let p = readPoint(base: base)
                path.addCurve(to: p, control1: c1, control2: c2); current = p
            case "Q", "q":
                let base: CGPoint? = command == "q" ? current : nil
                let ctrl = readPoint(base: base)
                let p = readPoint(base: base)
                path.addQuadCurve(to: p, control: ctrl); current = p
            case "Z", "z":
                path.closeSubpath(); current = start
                command = " "   // operands after Z are illegal; require a fresh command
            default:
                i += 1
            }
        }
    }

    private mutating func readPoint(base: CGPoint?) -> CGPoint {
        let x = readNumber()
        let y = readNumber()
        if let base { return CGPoint(x: Double(base.x) + x, y: Double(base.y) + y) }
        return CGPoint(x: x, y: y)
    }

    private mutating func readNumber() -> Double {
        skipSeparators()
        var s = ""
        if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
        var seenDot = false
        while i < chars.count {
            let c = chars[i]
            if c.isNumber {
                s.append(c); i += 1
            } else if c == "." && !seenDot {
                seenDot = true; s.append(c); i += 1
            } else {
                break
            }
        }
        return Double(s) ?? 0
    }

    private mutating func skipSeparators() {
        while i < chars.count {
            switch chars[i] {
            case " ", ",", "\n", "\t", "\r": i += 1
            default: return
            }
        }
    }
}
