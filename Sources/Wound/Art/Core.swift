import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Units: every watch is drawn in millimetres, origin at the dial centre, y up.
// Angles passed around as "cw" are clockwise radians from 12 o'clock, like hands.

let π = Double.pi
@inline(__always) func rad(_ d: Double) -> Double { d * π / 180 }
@inline(__always) func pol(_ r: Double, _ a: Double, _ c: CGPoint = .zero) -> CGPoint {
    CGPoint(x: c.x + r * sin(a), y: c.y + r * cos(a))
}
@inline(__always) func clamp(_ x: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double { min(hi, max(lo, x)) }
@inline(__always) func smooth(_ x: Double) -> Double { let t = clamp(x); return t * t * (3 - 2 * t) }
@inline(__always) func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
func dist(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
func angleTo(_ a: CGPoint, _ b: CGPoint) -> Double { atan2(b.x - a.x, b.y - a.y) } // cw from 12

/// Pixel scale of the current watch drawing (px per mm); shadows are specified in device space.
nonisolated(unsafe) var gScale: Double = 30

struct Col {
    var r, g, b, a: Double
    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: Double = 1) {
        r = Double((hex >> 16) & 0xff) / 255; g = Double((hex >> 8) & 0xff) / 255; b = Double(hex & 0xff) / 255; self.a = a
    }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    func mix(_ o: Col, _ t: Double) -> Col { Col(lerp(r, o.r, t), lerp(g, o.g, t), lerp(b, o.b, t), lerp(a, o.a, t)) }
    func alpha(_ x: Double) -> Col { Col(r, g, b, x) }
    func scaled(_ k: Double) -> Col { Col(min(1, r * k), min(1, g * k), min(1, b * k), a) }
    static let white = Col(1, 1, 1), black = Col(0, 0, 0), clear = Col(0, 0, 0, 0)
}

/// Metal palette: dark, mid, light, specular.
struct Metal {
    var dark, mid, light, spec: Col
    func at(_ t: Double) -> Col {
        let x = clamp(t)
        if x < 0.5 { return dark.mix(mid, x * 2) }
        if x < 0.85 { return mid.mix(light, (x - 0.5) / 0.35) }
        return light.mix(spec, (x - 0.85) / 0.15)
    }
    static let steel = Metal(dark: Col(hex: 0x3a3e44), mid: Col(hex: 0x8c939b), light: Col(hex: 0xd9dde2), spec: Col(hex: 0xffffff))
    static let rhodium = Metal(dark: Col(hex: 0x5b6067), mid: Col(hex: 0xa8adb3), light: Col(hex: 0xe3e6ea), spec: Col(hex: 0xffffff))
    static let gold = Metal(dark: Col(hex: 0x6b4a14), mid: Col(hex: 0xb98a2e), light: Col(hex: 0xf0cf79), spec: Col(hex: 0xfff4cf))
    static let gilt = Metal(dark: Col(hex: 0x6e5323), mid: Col(hex: 0xc39b4d), light: Col(hex: 0xead08f), spec: Col(hex: 0xfff2cc))
    static let rose = Metal(dark: Col(hex: 0x6e3b2c), mid: Col(hex: 0xc0806a), light: Col(hex: 0xf0c3ad), spec: Col(hex: 0xfff0e6))
    static let blued = Metal(dark: Col(hex: 0x0b1240), mid: Col(hex: 0x1f3a9a), light: Col(hex: 0x5b86e6), spec: Col(hex: 0xc9dcff))
    static let titanium = Metal(dark: Col(hex: 0x1c1e22), mid: Col(hex: 0x484c53), light: Col(hex: 0x8a8f97), spec: Col(hex: 0xd7dbe0))
    static let ruby = Metal(dark: Col(hex: 0x3c0010), mid: Col(hex: 0x9c0f2e), light: Col(hex: 0xe8405e), spec: Col(hex: 0xffd0d8))
}

// MARK: - Drawing helpers

extension CGContext {
    func scoped(_ body: () -> Void) { saveGState(); body(); restoreGState() }
    func clipPath(_ p: CGPath, eo: Bool = false) { addPath(p); clip(using: eo ? .evenOdd : .winding) }
    func fill(_ p: CGPath, _ c: Col, eo: Bool = false) { addPath(p); setFillColor(c.cg); fillPath(using: eo ? .evenOdd : .winding) }
    func stroke(_ p: CGPath, _ c: Col, _ w: Double, cap: CGLineCap = .round, join: CGLineJoin = .round) {
        addPath(p); setStrokeColor(c.cg); setLineWidth(w); setLineCap(cap); setLineJoin(join); strokePath()
    }
    func shadow(_ dx: Double, _ dy: Double, _ blur: Double, _ c: Col) {
        // dx, dy, blur in mm; device space needs pixels.
        setShadow(offset: CGSize(width: dx * gScale, height: dy * gScale), blur: blur * gScale, color: c.cg)
    }
}

func gradient(_ stops: [(Double, Col)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: stops.map { $0.1.cg } as CFArray,
               locations: stops.map { CGFloat($0.0) })!
}

func linFill(_ ctx: CGContext, _ p: CGPath, _ stops: [(Double, Col)], _ a: CGPoint, _ b: CGPoint, eo: Bool = false) {
    ctx.scoped {
        ctx.clipPath(p, eo: eo)
        ctx.drawLinearGradient(gradient(stops), start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

func radFill(_ ctx: CGContext, _ p: CGPath, _ stops: [(Double, Col)], _ c0: CGPoint, _ r0: Double, _ c1: CGPoint, _ r1: Double, eo: Bool = false) {
    ctx.scoped {
        ctx.clipPath(p, eo: eo)
        ctx.drawRadialGradient(gradient(stops), startCenter: c0, startRadius: r0, endCenter: c1, endRadius: r1,
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

/// Anisotropic "polished" fill: colour as a function of angle around a centre (CG has no conic gradient).
func conicFill(_ ctx: CGContext, _ p: CGPath, center c: CGPoint, radius: Double, steps: Int = 240, eo: Bool = false, _ color: (Double) -> Col) {
    ctx.scoped {
        ctx.clipPath(p, eo: eo)
        ctx.setShouldAntialias(false)
        let d = 2 * π / Double(steps)
        for i in 0..<steps {
            let a0 = Double(i) * d, a1 = a0 + d * 1.6
            let w = CGMutablePath()
            w.move(to: c); w.addLine(to: pol(radius, a0, c)); w.addLine(to: pol(radius, (a0 + a1) / 2, c)); w.addLine(to: pol(radius, a1, c)); w.closeSubpath()
            ctx.fill(w, color(a0 + d / 2))
        }
    }
}

/// Polished metal brightness for a ring lit from `light` (cw angle): two broad lobes plus fine variation.
func polish(_ m: Metal, light: Double, contrast: Double = 1) -> (Double) -> Col {
    { a in
        let b = 0.5 + 0.34 * cos(2 * (a - light)) * contrast + 0.12 * cos(a - light) + 0.05 * cos(7 * a + 1.3)
        return m.at(b)
    }
}

func circle(_ c: CGPoint, _ r: Double) -> CGPath { CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil) }
func ring(_ c: CGPoint, _ r0: Double, _ r1: Double) -> CGPath {
    let p = CGMutablePath(); p.addPath(circle(c, r1)); p.addPath(circle(c, r0)); return p
}
func ellipse(_ c: CGPoint, _ rx: Double, _ ry: Double) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry), transform: nil)
}
func poly(_ pts: [CGPoint], closed: Bool = true) -> CGMutablePath {
    let p = CGMutablePath(); guard let f = pts.first else { return p }
    p.move(to: f); for q in pts.dropFirst() { p.addLine(to: q) }; if closed { p.closeSubpath() }; return p
}
func arcPath(_ c: CGPoint, _ r: Double, _ a0: Double, _ a1: Double, n: Int = 64) -> CGMutablePath {
    poly((0...n).map { pol(r, lerp(a0, a1, Double($0) / Double(n)), c) }, closed: false)
}
/// Annular sector between cw angles a0..a1.
func sector(_ c: CGPoint, _ r0: Double, _ r1: Double, _ a0: Double, _ a1: Double, n: Int = 48) -> CGMutablePath {
    var pts: [CGPoint] = []
    for i in 0...n { pts.append(pol(r1, lerp(a0, a1, Double(i) / Double(n)), c)) }
    for i in (0...n).reversed() { pts.append(pol(r0, lerp(a0, a1, Double(i) / Double(n)), c)) }
    return poly(pts)
}
/// Thick curved band ("bridge") along a polyline of centre points with constant width, round ends.
func band(_ pts: [CGPoint], width: Double) -> CGPath {
    let p = CGMutablePath(); p.addLines(between: pts)
    return p.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4).normalized()
}
func smoothCurve(_ pts: [CGPoint], samples: Int = 12) -> [CGPoint] {
    // Catmull-Rom through points.
    guard pts.count > 2 else { return pts }
    var out: [CGPoint] = []
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
        for s in 0..<samples {
            let t = Double(s) / Double(samples), t2 = t * t, t3 = t2 * t
            let x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
            let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
            out.append(CGPoint(x: x, y: y))
        }
    }
    out.append(pts.last!)
    return out
}

func rotated(_ p: CGPath, about c: CGPoint, cw: Double) -> CGPath {
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: -cw).translatedBy(x: -c.x, y: -c.y)
    return p.copy(using: &t)!
}

// MARK: - Deterministic noise

struct RNG {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> Double { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return Double(s % 1_000_000) / 1_000_000 }
}

/// Circular graining / brushing: many concentric hairlines of random brightness.
func circularGrain(_ ctx: CGContext, clip: CGPath, center c: CGPoint, r0: Double, r1: Double, step: Double, alpha: Double, seed: UInt64 = 7, eo: Bool = false) {
    var g = RNG(seed)
    ctx.scoped {
        ctx.clipPath(clip, eo: eo)
        var r = r0
        while r < r1 {
            let v = g.next()
            ctx.stroke(circle(c, r), (v > 0.5 ? Col.white : Col.black).alpha(alpha * abs(v - 0.5) * 2), step * 0.9)
            r += step
        }
    }
}

/// Sunburst: fine radial hairlines.
func sunburst(_ ctx: CGContext, clip: CGPath, center c: CGPoint, r: Double, count: Int, alpha: Double, seed: UInt64 = 3) {
    var g = RNG(seed)
    ctx.scoped {
        ctx.clipPath(clip)
        for i in 0..<count {
            let a = 2 * π * Double(i) / Double(count) + g.next() * 0.002
            let v = g.next()
            let p = CGMutablePath(); p.move(to: c); p.addLine(to: pol(r, a, c))
            ctx.stroke(p, (v > 0.5 ? Col.white : Col.black).alpha(alpha * abs(v - 0.5) * 2), r * 0.004, cap: .butt)
        }
    }
}

// MARK: - Text

func font(_ name: String, _ size: Double) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }

func textLine(_ s: String, _ f: CTFont, _ c: Col, kern: Double = 0) -> CTLine {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): c.cg,
        NSAttributedString.Key(kCTKernAttributeName as String): kern,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
}

enum Align { case left, center, right }

/// Draw text with baseline-centre (or left/right) at p, rotated by cw angle.
@discardableResult
func drawText(_ ctx: CGContext, _ s: String, _ f: CTFont, _ c: Col, at p: CGPoint, align: Align = .center, kern: Double = 0, cw: Double = 0, vcenter: Bool = true) -> Double {
    let line = textLine(s, f, c, kern: kern)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    let capH = CTFontGetCapHeight(f)
    ctx.scoped {
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: -cw)
        let x: Double = align == .left ? 0 : (align == .center ? -w / 2 : -w)
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: vcenter ? -capH / 2 : 0)
        CTLineDraw(line, ctx)
    }
    return w
}

/// Text set along a circle, centred on cw angle `mid`. `bottom` = reads left-to-right along the lower arc.
func arcText(_ ctx: CGContext, _ s: String, _ f: CTFont, _ c: Col, center: CGPoint, radius: Double, mid: Double, bottom: Bool = false, kern: Double = 0) {
    let chars = s.map { String($0) }
    let widths = chars.map { CTLineGetTypographicBounds(textLine($0, f, c), nil, nil, nil) + kern }
    let total = widths.reduce(0, +)
    var acc = -total / 2
    for (i, ch) in chars.enumerated() {
        let cx = acc + widths[i] / 2
        acc += widths[i]
        let a = bottom ? mid - cx / radius : mid + cx / radius
        drawText(ctx, ch, f, c, at: pol(radius, a, center), cw: bottom ? a + π : a)
    }
}

// MARK: - Bitmap output

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldSmoothFonts(false)
    return ctx
}

func savePNG(_ ctx: CGContext, _ path: String) {
    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

/// Run `body` in watch space: centre at pixel point, `scale` px per mm.
func inWatch(_ ctx: CGContext, center: CGPoint, scale: Double, _ body: () -> Void) {
    let old = gScale
    gScale = scale
    ctx.scoped {
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: scale, y: scale)
        body()
    }
    gScale = old
}
