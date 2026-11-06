import Foundation
import CoreGraphics

let LIGHT = rad(-35) // key light from upper left (cw from 12)

// MARK: - Gears

func gearPath(_ c: CGPoint, teeth n: Int, r: Double, rot: Double, leaf: Bool = false) -> CGMutablePath {
    let m = 2 * r / Double(n)
    let tip = r + (leaf ? 0.75 : 0.95) * m, root = r - 1.2 * m
    let k = n > 60 ? 8 : 14
    var pts: [CGPoint] = []
    for i in 0..<(n * k) {
        let u = Double(i) / Double(k)
        let d = abs(u - floor(u) - 0.5)
        var h: Double
        if leaf {
            h = d < 0.25 ? sqrt(max(0, 1 - pow(d / 0.25, 2))) : 0
        } else if d < 0.15 {
            h = 1 - pow(d / 0.15, 2) * 0.12
        } else if d < 0.29 {
            h = (1 - smooth((d - 0.15) / 0.14)) * 0.88
        } else { h = 0 }
        pts.append(pol(root + (tip - root) * h, rot + 2 * π * u / Double(n), c))
    }
    return poly(pts)
}

func spokeCutouts(_ c: CGPoint, n: Int, rIn: Double, rOut: Double, spokeW: Double, rot: Double, curve: Double) -> [CGPath] {
    var out: [CGPath] = []
    let steps = 18
    for i in 0..<n {
        let a0 = rot + 2 * π * Double(i) / Double(n), a1 = a0 + 2 * π / Double(n)
        func off(_ r: Double) -> Double { curve * pow((r - rIn) / (rOut - rIn), 1.3) }
        func hw(_ r: Double) -> Double { (spokeW / 2) / r }
        var pts: [CGPoint] = []
        for s in 0...steps { let t = Double(s) / Double(steps); pts.append(pol(rOut, lerp(a0 + off(rOut) + hw(rOut), a1 + off(rOut) - hw(rOut), t), c)) }
        for s in 0...steps { let r = lerp(rOut, rIn, Double(s) / Double(steps)); pts.append(pol(r, a1 + off(r) - hw(r), c)) }
        for s in 0...steps { let t = Double(s) / Double(steps); pts.append(pol(rIn, lerp(a1 + off(rIn) - hw(rIn), a0 + off(rIn) + hw(rIn), t), c)) }
        for s in 0...steps { let r = lerp(rIn, rOut, Double(s) / Double(steps)); pts.append(pol(r, a0 + off(r) + hw(r), c)) }
        // Round the corners slightly by insetting and re-stroking.
        let p = poly(pts)
        out.append(p)
    }
    return out
}

struct WheelSpec {
    var teeth: Int
    var r: Double
    var metal: Metal = .gilt
    var spokes: Int = 5
    var curve: Double = 0.45
    var spokeW: Double = 0.42
    var rimW: Double = 0.55
    var hubR: Double = 0.9
    var pinionLeaves: Int = 0
    var pinionR: Double = 0
    var jewel: Bool = true
}

func drawWheel(_ ctx: CGContext, _ c: CGPoint, _ w: WheelSpec, rot: Double, shadow: Bool = true) {
    let outline = gearPath(c, teeth: w.teeth, r: w.r, rot: rot)
    let m = 2 * w.r / Double(w.teeth)
    let rimIn = w.r - 1.2 * m - w.rimW
    let body = CGMutablePath(); body.addPath(outline)
    let cuts = w.spokes > 0 ? spokeCutouts(c, n: w.spokes, rIn: w.hubR, rOut: rimIn, spokeW: w.spokeW, rot: rot, curve: w.curve) : []
    for p in cuts { body.addPath(p) }
    if shadow {
        ctx.scoped { ctx.shadow(0.18, -0.3, 0.45, Col(0, 0, 0, 0.75)); ctx.fill(body, w.metal.dark, eo: true) }
    }
    conicFill(ctx, body, center: c, radius: w.r + 1, steps: 180, eo: true, polish(w.metal, light: LIGHT, contrast: 0.9))
    circularGrain(ctx, clip: body, center: c, r0: 0.2, r1: w.r + 0.3, step: 0.05, alpha: 0.12, seed: UInt64(w.teeth), eo: true)
    // Anglage: bright bevel on inner edges, dark on outline.
    for p in cuts { ctx.stroke(p, w.metal.spec.alpha(0.55), 0.06) }
    ctx.stroke(outline, w.metal.dark.alpha(0.5), 0.04)
    if w.pinionLeaves > 0 {
        let pin = gearPath(c, teeth: w.pinionLeaves, r: w.pinionR, rot: rot * 1.0, leaf: true)
        ctx.scoped { ctx.shadow(0.05, -0.1, 0.15, Col(0, 0, 0, 0.6)); ctx.fill(pin, Metal.steel.dark) }
        conicFill(ctx, pin, center: c, radius: w.pinionR + 0.5, steps: 90, polish(.steel, light: LIGHT))
    }
    if w.jewel { jewel(ctx, c, w.hubR * 0.42) } else {
        radFill(ctx, circle(c, w.hubR * 0.45), [(0, Metal.steel.spec), (1, Metal.steel.dark)], pol(0.1, -0.7, c), 0, c, w.hubR * 0.45)
    }
}

// MARK: - Jewels and screws

func jewel(_ ctx: CGContext, _ p: CGPoint, _ r: Double, chaton: Metal? = .gold) {
    if let ch = chaton {
        let cp = circle(p, r * 1.95)
        ctx.scoped { ctx.shadow(0.04, -0.08, 0.12, Col(0, 0, 0, 0.6)); ctx.fill(cp, ch.dark) }
        conicFill(ctx, cp, center: p, radius: r * 2.2, steps: 90, polish(ch, light: LIGHT, contrast: 1.2))
        ctx.stroke(circle(p, r * 1.95), ch.dark.alpha(0.8), r * 0.08)
        ctx.stroke(circle(p, r * 1.3), ch.spec.alpha(0.6), r * 0.08)
    }
    radFill(ctx, circle(p, r), [(0, Metal.ruby.spec), (0.25, Metal.ruby.light), (0.65, Metal.ruby.mid), (1, Metal.ruby.dark)],
            CGPoint(x: p.x - r * 0.35, y: p.y + r * 0.35), 0, p, r)
    ctx.fill(circle(p, r * 0.3), Col(hex: 0x2a0008))
    ctx.fill(circle(p, r * 0.16), Metal.steel.light)
    ctx.fill(ellipse(CGPoint(x: p.x - r * 0.42, y: p.y + r * 0.45), r * 0.22, r * 0.14), Col(1, 1, 1, 0.85))
    ctx.stroke(arcPath(p, r * 0.82, rad(100), rad(200), n: 12), Col(1, 0.75, 0.8, 0.5), r * 0.1)
}

func screw(_ ctx: CGContext, _ p: CGPoint, _ r: Double, slot: Double, metal: Metal = .blued) {
    ctx.fill(circle(p, r * 1.18), Col(0, 0, 0, 0.55))
    let head = circle(p, r)
    radFill(ctx, head, [(0, metal.spec), (0.18, metal.light), (0.7, metal.mid), (1, metal.dark)],
            CGPoint(x: p.x - r * 0.35, y: p.y + r * 0.4), 0, p, r * 1.05)
    let s = poly([pol(r * 1.02, slot - 0.16, p), pol(r * 1.02, slot + 0.16, p), pol(r * 1.02, slot + π - 0.16, p), pol(r * 1.02, slot + π + 0.16, p)])
    ctx.scoped { ctx.clipPath(head); ctx.fill(s, Col(0.02, 0.02, 0.05, 0.92)) }
    ctx.stroke(arcPath(p, r * 0.92, rad(160), rad(290), n: 16), Col(0, 0, 0, 0.35), r * 0.12)
    ctx.fill(ellipse(CGPoint(x: p.x - r * 0.42, y: p.y + r * 0.5), r * 0.2, r * 0.12), metal.spec.alpha(0.9))
}

// MARK: - Regulating organ

func balanceWheel(_ ctx: CGContext, _ c: CGPoint, R: Double, rot: Double, metal: Metal = .gold, arms: Int = 3, screws: Int = 18) {
    let rimIn = R * 0.84
    let rimP = ring(c, rimIn, R)
    var armsP = CGMutablePath()
    for k in 0..<arms {
        let a = rot + 2 * π * Double(k) / Double(arms)
        let p = CGMutablePath(); p.move(to: c); p.addLine(to: pol(rimIn + 0.05, a, c))
        armsP.addPath(p.copy(strokingWithWidth: R * 0.13, lineCap: .butt, lineJoin: .round, miterLimit: 2))
    }
    let hub = circle(c, R * 0.17)
    armsP.addPath(hub)
    let whole = CGMutablePath(); whole.addPath(rimP); whole.addPath(armsP)
    ctx.scoped { ctx.shadow(0.25, -0.4, 0.6, Col(0, 0, 0, 0.7)); ctx.fill(rimP, metal.dark, eo: true); ctx.fill(armsP, metal.dark) }
    conicFill(ctx, rimP, center: c, radius: R + 1, steps: 200, eo: true, polish(metal, light: LIGHT, contrast: 1.1))
    conicFill(ctx, armsP, center: c, radius: R, steps: 160, polish(metal, light: LIGHT + 0.6, contrast: 0.8))
    ctx.stroke(circle(c, R), metal.spec.alpha(0.5), 0.05)
    ctx.stroke(circle(c, rimIn), metal.dark.alpha(0.7), 0.05)
    armsP = CGMutablePath()
    // Timing screws on the rim.
    for i in 0..<screws {
        let a = rot + 2 * π * (Double(i) + 0.5) / Double(screws)
        let sp = pol(R + R * 0.035, a, c)
        let sr = R * 0.062
        radFill(ctx, circle(sp, sr), [(0, metal.spec), (0.4, metal.light), (1, metal.dark)], pol(sr * 0.5, LIGHT, sp), 0, sp, sr)
        let l = CGMutablePath(); l.move(to: pol(sr, a + π / 2, sp)); l.addLine(to: pol(sr, a - π / 2, sp))
        ctx.stroke(l, Col(0, 0, 0, 0.6), sr * 0.28)
    }
    // Roller with ruby impulse pin.
    ctx.fill(circle(c, R * 0.2), Metal.steel.mid)
    conicFill(ctx, circle(c, R * 0.2), center: c, radius: R * 0.3, steps: 60, polish(.steel, light: LIGHT))
    ctx.fill(circle(pol(R * 0.15, rot + π, c), R * 0.035), Metal.ruby.light)
}

/// Flat hairspring whose inner end turns with the balance and outer end is pinned at the stud.
func hairspring(_ ctx: CGContext, _ c: CGPoint, r0: Double, r1: Double, turns: Double, bal: Double, stud: Double, color: Col = Col(hex: 0xc7ccd6), width: Double = 0.055) {
    let N = Int(turns * 80)
    var pts: [CGPoint] = []
    let breath = 0.075 * bal / (1.5 * π)
    for i in 0...N {
        let s = Double(i) / Double(N)
        let a = stud - 2 * π * turns * (1 - s) + bal * (1 - s)
        let r = (r0 + (r1 - r0) * s) * (1 - breath * sin(π * s) * 1.2)
        pts.append(pol(r, a, c))
    }
    // Overcoil terminal to the stud.
    let end = pol(r1, stud, c)
    pts.append(pol(r1 * 1.05, stud + 0.18, c)); pts.append(pol(r1 * 1.1, stud + 0.3, c))
    let p = poly(pts, closed: false)
    ctx.stroke(p, Col(0, 0, 0, 0.45), width * 2.2)
    ctx.stroke(p, color, width)
    ctx.stroke(p, Col(1, 1, 1, 0.35), width * 0.35)
    _ = end
    let st = pol(r1 * 1.1, stud + 0.3, c)
    ctx.fill(circle(st, 0.32), Metal.steel.dark)
    radFill(ctx, circle(st, 0.28), [(0, Metal.steel.spec), (1, Metal.steel.mid)], pol(0.1, LIGHT, st), 0, st, 0.28)
}

func escapeWheel(_ ctx: CGContext, _ c: CGPoint, R: Double, rot: Double, metal: Metal = .steel) {
    var pts: [CGPoint] = []
    let shape: [(Double, Double)] = [(0.70, -0.13), (0.80, -0.06), (0.97, 0.07), (1.0, 0.13), (0.95, 0.17), (0.78, 0.10), (0.70, 0.08)]
    for i in 0..<15 {
        let b = rot - 2 * π * Double(i) / 15
        for (rr, da) in shape { pts.append(pol(R * rr, b - da, c)) }
    }
    let outline = poly(pts)
    let body = CGMutablePath(); body.addPath(outline)
    let cuts = spokeCutouts(c, n: 4, rIn: R * 0.22, rOut: R * 0.6, spokeW: R * 0.11, rot: rot, curve: -0.5)
    for p in cuts { body.addPath(p) }
    ctx.scoped { ctx.shadow(0.12, -0.2, 0.3, Col(0, 0, 0, 0.75)); ctx.fill(body, metal.dark, eo: true) }
    conicFill(ctx, body, center: c, radius: R + 0.5, steps: 120, eo: true, polish(metal, light: LIGHT, contrast: 1.2))
    for p in cuts { ctx.stroke(p, metal.spec.alpha(0.6), 0.04) }
    jewel(ctx, c, R * 0.15)
}

/// Swiss lever: pivot P, base direction toward balance `dir` (cw), rocking angle `rock`.
func palletFork(_ ctx: CGContext, pivot P: CGPoint, dir: Double, length L: Double, span: Double, rock: Double, metal: Metal = .steel) {
    let a = dir + rock
    let back = a + π
    let armL = span
    let entry = pol(armL, back - rad(52), P), exit = pol(armL, back + rad(52), P)
    let tip = pol(L, a, P)
    var body = CGMutablePath()
    body.addPath(band([entry, P, exit], width: 0.42))
    body.addPath(band([P, pol(L * 0.82, a, P)], width: 0.32))
    let hornL = pol(0.42, a - π / 2, tip), hornR = pol(0.42, a + π / 2, tip)
    body.addPath(band([pol(L * 0.8, a, P), pol(0.3, a - π / 2, pol(L * 0.92, a, P)), hornL], width: 0.2))
    body.addPath(band([pol(L * 0.8, a, P), pol(0.3, a + π / 2, pol(L * 0.92, a, P)), hornR], width: 0.2))
    ctx.scoped { ctx.shadow(0.1, -0.18, 0.28, Col(0, 0, 0, 0.7)); ctx.fill(body, metal.dark) }
    linFill(ctx, body, [(0, metal.light), (0.5, metal.mid), (1, metal.dark)], pol(L, LIGHT, P), pol(L, LIGHT + π, P))
    ctx.stroke(body, metal.spec.alpha(0.35), 0.03)
    body = CGMutablePath()
    // Ruby pallet stones.
    for (e, s) in [(entry, -1.0), (exit, 1.0)] {
        let d = angleTo(P, e) + s * rad(25)
        let st = band([e, pol(0.55, d, e)], width: 0.22)
        ctx.fill(st, Metal.ruby.mid)
        linFill(ctx, st, [(0, Metal.ruby.spec), (0.35, Metal.ruby.light), (1, Metal.ruby.dark)], pol(0.3, LIGHT, e), pol(0.3, LIGHT + π, e))
    }
    jewel(ctx, P, 0.2)
}

/// Mainspring inside the barrel: `wound` 0 = coils relaxed against the wall, 1 = packed around the arbor.
func mainspring(_ ctx: CGContext, _ c: CGPoint, rArbor: Double, rWall: Double, wound: Double, arbor: Double, drum: Double, coils: Int = 11) {
    let n = Double(coils)
    let gap = (rWall - rArbor) * 0.62 / n
    let N = coils * 72
    var pts: [CGPoint] = []
    let split = n * clamp(wound)
    for i in 0...N {
        let u = Double(i) / Double(N) * n
        let inner = rArbor + 0.15 + gap * (n - u) * (1 - 0.0)
        let outer = rWall - 0.12 - gap * (n - u)
        // Coils above `split` (outer end) stay packed outside; below it they are packed on the arbor.
        let t = smooth((u - split) / 1.6 + 0.5)
        let rInner = rArbor + 0.15 + gap * u
        let r = lerp(rInner, outer, t)
        _ = inner
        let a = 2 * π * u + arbor * (1 - u / n) + drum * (u / n)
        pts.append(pol(r, a, c))
    }
    let p = poly(pts, closed: false)
    ctx.stroke(p, Col(0, 0, 0, 0.6), gap * 0.9)
    ctx.stroke(p, Col(hex: 0xb8c0cc), gap * 0.55)
    ctx.stroke(p, Col(1, 1, 1, 0.45), gap * 0.18)
}

// MARK: - Hands

enum HandStyle { case skeletonBaton, dauphine, sword, leaf, needle }

func handPath(_ style: HandStyle, length L: Double, width W: Double, tail: Double) -> (CGPath, CGPath?) {
    // Built pointing to 12 at origin; caller rotates.
    switch style {
    case .skeletonBaton:
        let outer = poly([CGPoint(x: -W / 2, y: -tail), CGPoint(x: -W / 2, y: L - W * 1.2), CGPoint(x: 0, y: L), CGPoint(x: W / 2, y: L - W * 1.2), CGPoint(x: W / 2, y: -tail)])
        let hole = poly([CGPoint(x: -W * 0.22, y: W * 2.2), CGPoint(x: -W * 0.22, y: L - W * 1.7), CGPoint(x: 0, y: L - W * 1.1), CGPoint(x: W * 0.22, y: L - W * 1.7), CGPoint(x: W * 0.22, y: W * 2.2)])
        let p = CGMutablePath(); p.addPath(outer); p.addPath(hole); p.addPath(circle(.zero, W * 0.95))
        return (p, hole)
    case .dauphine:
        let p = poly([CGPoint(x: 0, y: L), CGPoint(x: -W / 2, y: L * 0.18), CGPoint(x: -W * 0.22, y: -tail), CGPoint(x: W * 0.22, y: -tail), CGPoint(x: W / 2, y: L * 0.18)])
        return (p, nil)
    case .sword:
        let p = poly([CGPoint(x: 0, y: L), CGPoint(x: -W / 2, y: L * 0.72), CGPoint(x: -W * 0.32, y: -tail), CGPoint(x: W * 0.32, y: -tail), CGPoint(x: W / 2, y: L * 0.72)])
        return (p, nil)
    case .leaf:
        var pts: [CGPoint] = []
        for i in 0...40 { let t = Double(i) / 40; pts.append(CGPoint(x: -W / 2 * sin(π * pow(t, 0.8)), y: lerp(-tail, L, t))) }
        for i in (0...40).reversed() { let t = Double(i) / 40; pts.append(CGPoint(x: W / 2 * sin(π * pow(t, 0.8)), y: lerp(-tail, L, t))) }
        return (poly(pts), nil)
    case .needle:
        let p = poly([CGPoint(x: -W / 2, y: -tail), CGPoint(x: -W * 0.3, y: L), CGPoint(x: W * 0.3, y: L), CGPoint(x: W / 2, y: -tail)])
        return (p, nil)
    }
}

/// Draws a hand with a cast shadow and faceted (two-tone) finish.
func drawHand(_ ctx: CGContext, _ c: CGPoint, cw: Double, style: HandStyle, length: Double, width: Double, tail: Double, metal: Metal, height: Double = 0.6, lume: Col? = nil) {
    let (base, _) = handPath(style, length: length, width: width, tail: tail)
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: -cw)
    let p = base.copy(using: &t)!
    let eo = style == .skeletonBaton
    ctx.scoped { ctx.shadow(height * 0.5, -height * 0.9, height * 1.1, Col(0, 0, 0, 0.55)); ctx.fill(p, metal.dark, eo: eo) }
    // Facets: left half lit, right half darker (dauphine/sword), else axial gradient.
    if style == .dauphine || style == .sword || style == .leaf {
        let leftHalf = poly([CGPoint(x: 0, y: length + 1), CGPoint(x: -width * 2, y: length), CGPoint(x: -width * 2, y: -tail - 1), CGPoint(x: 0, y: -tail - 1)])
        let lh = leftHalf.copy(using: &t)!
        let lightLeft = cos(cw - LIGHT + π / 2) > 0
        ctx.fill(p, metal.at(lightLeft ? 0.45 : 0.9))
        ctx.scoped { ctx.clipPath(p); ctx.fill(lh, metal.at(lightLeft ? 0.95 : 0.4)) }
        let ridge = CGMutablePath(); ridge.move(to: CGPoint(x: 0, y: length)); ridge.addLine(to: CGPoint(x: 0, y: -tail))
        ctx.stroke(ridge.copy(using: &t)!, metal.spec.alpha(0.5), width * 0.05)
    } else {
        linFill(ctx, p, [(0, metal.spec), (0.3, metal.light), (0.7, metal.mid), (1, metal.dark)],
                pol(width, cw - π / 2, c), pol(width, cw + π / 2, c), eo: eo)
    }
    if let lume = lume, style == .skeletonBaton {
        _ = lume
    }
    ctx.stroke(p, metal.dark.alpha(0.6), width * 0.04)
}

func handCap(_ ctx: CGContext, _ c: CGPoint, r: Double, metal: Metal) {
    ctx.scoped { ctx.shadow(0.2, -0.35, 0.4, Col(0, 0, 0, 0.6)); ctx.fill(circle(c, r), metal.dark) }
    conicFill(ctx, circle(c, r), center: c, radius: r * 1.4, steps: 72, polish(metal, light: LIGHT, contrast: 1.3))
    ctx.fill(circle(c, r * 0.35), metal.dark.alpha(0.6))
    ctx.fill(ellipse(pol(r * 0.45, LIGHT, c), r * 0.25, r * 0.15), metal.spec.alpha(0.8))
}
