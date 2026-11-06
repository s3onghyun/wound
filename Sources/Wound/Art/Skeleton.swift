import Foundation
import CoreGraphics

let skelCase = CaseStyle(metal: .steel, R: 21, bezelIn: 19.0, strap: Col(hex: 0x17171a), stitch: Col(hex: 0x8a8a8a))

enum BridgeFinish { case polished, cotes, frosted }

/// A movement bridge or plate arm: shadow, base metal, finish, and bevelled (anglage) edge.
func drawBridge(_ ctx: CGContext, _ p: CGPath, metal: Metal = .rhodium, finish: BridgeFinish = .polished, stripeAngle: Double = rad(30), eo: Bool = false) {
    ctx.scoped { ctx.shadow(0.3, -0.5, 0.7, Col(0, 0, 0, 0.75)); ctx.fill(p, metal.dark, eo: eo) }
    let bb = p.boundingBoxOfPath
    let c = CGPoint(x: bb.midX, y: bb.midY)
    let span = max(bb.width, bb.height)
    linFill(ctx, p, [(0, metal.light), (0.45, metal.mid), (0.75, metal.light), (1, metal.mid)], pol(span / 2, LIGHT, c), pol(span / 2, LIGHT + π, c), eo: eo)
    switch finish {
    case .cotes:
        // Côtes de Genève: parallel bands, each a light-to-dark ridge.
        ctx.scoped {
            ctx.clipPath(p, eo: eo)
            let w = 1.25
            let dir = stripeAngle
            let n = Int(span / w) + 6
            for i in -n...n {
                let o = Double(i) * w
                let a = pol(o, dir + π / 2, c)
                let q = band([pol(span, dir, a), pol(span, dir + π, a)], width: w)
                linFill(ctx, q, [(0, metal.dark.alpha(0.35)), (0.35, metal.spec.alpha(0.35)), (0.55, metal.light.alpha(0.0)), (1, metal.dark.alpha(0.3))],
                        pol(w / 2, dir - π / 2, a), pol(w / 2, dir + π / 2, a))
            }
        }
    case .frosted:
        var g = RNG(5)
        ctx.scoped {
            ctx.clipPath(p, eo: eo)
            for _ in 0..<Int(bb.width * bb.height * 6) {
                let q = CGPoint(x: bb.minX + g.next() * bb.width, y: bb.minY + g.next() * bb.height)
                ctx.fill(circle(q, 0.05), (g.next() > 0.5 ? Col.white : Col.black).alpha(0.12))
            }
        }
    case .polished:
        ctx.scoped {
            ctx.clipPath(p, eo: eo)
            var g = RNG(9)
            for _ in 0..<40 {
                let a = CGPoint(x: bb.minX + g.next() * bb.width, y: bb.minY + g.next() * bb.height)
                let l = CGMutablePath(); l.move(to: pol(3, rad(60), a)); l.addLine(to: pol(3, rad(240), a))
                ctx.stroke(l, Col(1, 1, 1, 0.05), 0.08)
            }
        }
    }
    // Anglage: bright inner bevel and dark outer edge.
    ctx.scoped { ctx.clipPath(p, eo: eo); ctx.stroke(p, metal.spec.alpha(0.85), 0.34) }
    ctx.scoped { ctx.clipPath(p, eo: eo); ctx.stroke(p, metal.dark.alpha(0.5), 0.1) }
}

func ratchetPath(_ c: CGPoint, teeth n: Int, r: Double, rot: Double) -> CGMutablePath {
    var pts: [CGPoint] = []
    for i in 0..<n {
        let a = rot + 2 * π * Double(i) / Double(n), d = 2 * π / Double(n)
        pts.append(pol(r * 0.93, a, c)); pts.append(pol(r, a + d * 0.85, c)); pts.append(pol(r * 0.93, a + d * 0.9, c))
    }
    return poly(pts)
}

/// Ratchet wheel + click on the barrel arbor (the part that turns when the crown is wound).
func drawRatchet(_ ctx: CGContext, _ c: CGPoint, r: Double, rot: Double, clickAt: Double, openwork: Bool) {
    let n = 42
    let outline = ratchetPath(c, teeth: n, r: r, rot: rot)
    let body = CGMutablePath(); body.addPath(outline)
    if openwork { for p in spokeCutouts(c, n: 3, rIn: 1.35, rOut: r * 0.8, spokeW: 0.55, rot: rot, curve: 0.9) { body.addPath(p) } }
    ctx.scoped { ctx.shadow(0.2, -0.35, 0.5, Col(0, 0, 0, 0.75)); ctx.fill(body, Metal.steel.dark, eo: true) }
    // Soleil (sunray) finish typical of ratchet/crown wheels.
    conicFill(ctx, body, center: c, radius: r + 0.5, steps: 240, eo: true) { a in
        let k = 0.5 + 0.3 * cos(2 * (a - LIGHT)) + 0.18 * sin(37 * a) * 0.3
        return Metal.steel.at(k)
    }
    sunburst(ctx, clip: body, center: c, r: r, count: 260, alpha: 0.25, seed: 4)
    ctx.stroke(outline, Metal.steel.dark.alpha(0.7), 0.05)
    screw(ctx, c, 1.15, slot: rot + rad(20))
    // Click (pawl) riding the teeth: its tip lifts and drops with each tooth.
    let tooth = 2 * π / Double(n)
    let ph = (rot / tooth).truncatingRemainder(dividingBy: 1)
    let lift = 0.22 * (ph < 0 ? ph + 1 : ph)
    let pivot = pol(r + 1.25, clickAt - 0.42, c)
    let tip = pol(r * 0.95 + lift, clickAt, c)
    let pawl = band([pivot, pol(r + 0.55, clickAt - 0.2, c), tip], width: 0.62)
    drawBridge(ctx, pawl, metal: .steel)
    screw(ctx, pivot, 0.42, slot: rad(70))
    // Click spring (blued wire).
    let spring = poly(smoothCurve([pol(r + 0.6, clickAt - 0.1, c), pol(r + 1.4, clickAt + 0.12, c), pol(r + 2.0, clickAt + 0.35, c)], samples: 8), closed: false)
    ctx.stroke(spring, Metal.blued.mid, 0.16)
    ctx.stroke(spring, Metal.blued.light.alpha(0.6), 0.05)
}

func drawBarrel(_ ctx: CGContext, _ c: CGPoint, R: Double, drum: Double, arbor: Double, wound: Double) {
    let teeth = gearPath(c, teeth: 84, r: R, rot: drum)
    ctx.scoped { ctx.shadow(0.3, -0.5, 0.7, Col(0, 0, 0, 0.8)); ctx.fill(teeth, Metal.gilt.dark) }
    conicFill(ctx, teeth, center: c, radius: R + 1, steps: 240, polish(.gilt, light: LIGHT))
    // Barrel interior (dark) with the mainspring.
    let inner = R - 0.85
    radFill(ctx, circle(c, inner), [(0, Col(hex: 0x24262b)), (1, Col(hex: 0x0b0c0e))], c, 0, c, inner)
    mainspring(ctx, c, rArbor: 1.25, rWall: inner - 0.05, wound: wound, arbor: arbor, drum: drum)
    // Openworked barrel cover.
    let coverRing = ring(c, inner - 0.45, inner + 0.02)
    let cover = CGMutablePath()
    for k in 0..<5 {
        let a = drum + 2 * π * Double(k) / 5
        let s = poly(smoothCurve([pol(1.2, a, c), pol(inner * 0.5, a + 0.45, c), pol(inner - 0.3, a + 0.6, c)], samples: 8), closed: false)
        cover.addPath(s.copy(strokingWithWidth: 0.3, lineCap: .round, lineJoin: .round, miterLimit: 2))
    }
    cover.addPath(circle(c, 1.25))
    ctx.scoped { ctx.shadow(0.12, -0.2, 0.3, Col(0, 0, 0, 0.7)); ctx.fill(cover, Metal.gilt.dark); ctx.fill(coverRing, Metal.gilt.dark, eo: true) }
    conicFill(ctx, cover, center: c, radius: R, steps: 200, polish(.gilt, light: LIGHT + 0.4, contrast: 0.9))
    conicFill(ctx, coverRing, center: c, radius: R, steps: 200, eo: true, polish(.gilt, light: LIGHT + 0.4, contrast: 0.9))
    ctx.stroke(circle(c, inner - 0.45), Metal.gilt.spec.alpha(0.5), 0.05)
}

// MARK: - Concept A: skeleton, dial side

func skelBridges(_ L: SkelLayout) -> [CGPath] {
    let rr = 16.0
    return [
        // Outer plate ring.
        ring(.zero, 15.5, 16.6),
        // Barrel bridge: an arch across the barrel arbor.
        band(smoothCurve([pol(rr, rad(-68)), CGPoint(x: -7.0, y: 10.4), L.barrel, CGPoint(x: 7.0, y: 10.4), pol(rr, rad(68))]), width: 1.35),
        // Train bridge: one sweep through third, fourth and escape pivots.
        band(smoothCurve([pol(rr, rad(84)), CGPoint(x: 9.4, y: 0.6), L.third, CGPoint(x: 7.4, y: -3.3), L.fourth, CGPoint(x: 5.8, y: -7.6), L.escape, pol(rr, rad(162))]), width: 0.95),
        // Pallet cock.
        band(smoothCurve([L.pallet, CGPoint(x: 2.2, y: -12.4), pol(rr, rad(172))]), width: 0.8),
        // Balance bridge (two-footed arch).
        band(smoothCurve([pol(rr, rad(236)), CGPoint(x: -7.6, y: -10.4), L.balance, CGPoint(x: -1.6, y: -13.4), pol(rr, rad(188))]), width: 1.05),
        // Left arm: carries the reserve indicator and the centre pivot.
        band(smoothCurve([pol(rr, rad(-112)), CGPoint(x: -10.6, y: 1.1), CGPoint(x: -5.0, y: 0.6), L.center]), width: 0.95),
    ]
}

func drawSkeletonFront(_ ctx: CGContext, _ st: MvState) {
    let L = SkelLayout()
    let cs = skelCase
    drawCaseUnder(ctx, cs)
    drawCrown(ctx, cs, turn: st.crown)
    let open = circle(.zero, cs.bezelIn)
    ctx.scoped {
        ctx.clipPath(open)
        radFill(ctx, open, [(0, Col(hex: 0x1d2129)), (0.7, Col(hex: 0x0b0d11)), (1, Col(hex: 0x050506))], CGPoint(x: -5, y: 7), 0, .zero, 19)
        // Hint of the oscillating weight seen through the open caseback.
        ctx.scoped {
            let s = sector(.zero, 9, 16, -st.rotor - π * 0.5, -st.rotor + π * 0.5)
            ctx.fill(s, Col(1, 0.85, 0.5, 0.045))
        }
        // Going train (behind the bridges).
        drawBarrel(ctx, L.barrel, R: L.barrelR, drum: st.barrel, arbor: st.ratchet, wound: st.reserve)
        drawWheel(ctx, L.center, WheelSpec(teeth: 80, r: L.centerR, spokes: 5, curve: 0.55, spokeW: 0.38, hubR: 1.0, jewel: false), rot: st.center)
        drawWheel(ctx, L.third, WheelSpec(teeth: 75, r: L.thirdR, spokes: 5, curve: -0.5, spokeW: 0.34, hubR: 0.8, pinionLeaves: 10, pinionR: 0.55), rot: st.third)
        drawWheel(ctx, L.fourth, WheelSpec(teeth: 80, r: L.fourthR, spokes: 4, curve: 0.5, spokeW: 0.32, hubR: 0.7, pinionLeaves: 10, pinionR: 0.5), rot: st.fourth)
        escapeWheel(ctx, L.escape, R: L.escapeR, rot: st.escape)
        drawWheel(ctx, L.crownWheel, WheelSpec(teeth: 30, r: L.crownWheelR, metal: .steel, spokes: 0, jewel: false), rot: -st.ratchet * L.ratchetR / L.crownWheelR)
        // Bridges.
        for (i, b) in skelBridges(L).enumerated() { drawBridge(ctx, b, metal: .rhodium, finish: .polished, eo: i == 0) }
        // Pivots: jewels in polished gold chatons held by blued screws.
        for (p, r) in [(L.third, 0.38), (L.fourth, 0.36), (L.escape, 0.32), (L.pallet, 0.3)] { jewel(ctx, p, r) }
        for (a, r) in [(-68.0, 16.0), (68, 16), (84, 16), (162, 16), (172, 16), (236, 16), (188, 16), (-112, 16), (0, 16.05), (120, 16.05), (-150, 16.05)] {
            screw(ctx, pol(r - 0.05, rad(a)), 0.5, slot: rad(a * 3.1))
        }
        screw(ctx, L.crownWheel, 0.75, slot: -st.ratchet * L.ratchetR / L.crownWheelR + 0.6)
        drawRatchet(ctx, L.barrel, r: 3.7, rot: st.ratchet, clickAt: rad(-38), openwork: true)
        // Escapement and regulating organ.
        palletFork(ctx, pivot: L.pallet, dir: L.forkDir, length: dist(L.pallet, L.balance) - 1.0, span: L.escapeR * 0.95, rock: st.fork)
        balanceWheel(ctx, L.balance, R: L.balanceR, rot: st.bal, metal: .gold, arms: 3, screws: 18)
        hairspring(ctx, L.balance, r0: 0.95, r1: 3.6, turns: 12, bal: st.bal, stud: rad(40))
        // Shock-protection setting (lyre spring) over the balance jewel.
        jewel(ctx, L.balance, 0.42)
        let lyre = poly(smoothCurve([pol(0.95, rad(-60), L.balance), pol(1.25, 0, L.balance), pol(0.95, rad(60), L.balance)], samples: 8), closed: false)
        ctx.stroke(lyre, Metal.gold.light, 0.13)
        let lyre2 = poly(smoothCurve([pol(0.95, rad(120), L.balance), pol(1.25, π, L.balance), pol(0.95, rad(240), L.balance)], samples: 8), closed: false)
        ctx.stroke(lyre2, Metal.gold.light, 0.13)
        // Regulator index.
        let idx = band([L.balance, pol(2.9, rad(-25), L.balance)], width: 0.25)
        drawBridge(ctx, idx, metal: .steel)

        drawReserveFan(ctx, CGPoint(x: -10.6, y: 1.1), r: 3.5, reserve: st.reserve, ink: .white)
        drawSmallSeconds(ctx, L.fourth, r: 2.6, seconds: st.seconds)
        // Chapter ring (casts a soft shadow on the movement).
        let chap = ring(.zero, 16.5, cs.bezelIn)
        ctx.scoped { ctx.shadow(0.2, -0.4, 0.9, Col(0, 0, 0, 0.9)); ctx.fill(chap, Col(hex: 0xc9c6bf), eo: true) }
        linFill(ctx, chap, [(0, Col(hex: 0xf1efe9)), (0.5, Col(hex: 0xcfccc4)), (1, Col(hex: 0xa9a59c))], CGPoint(x: -12, y: 15), CGPoint(x: 12, y: -15), eo: true)
        circularGrain(ctx, clip: chap, center: .zero, r0: 16.5, r1: 19, step: 0.035, alpha: 0.18, eo: true)
        let ink = Col(hex: 0x14161c)
        for i in 0..<60 {
            let a = 2 * π * Double(i) / 60
            let big = i % 5 == 0
            let l = CGMutablePath(); l.move(to: pol(18.35, a)); l.addLine(to: pol(big ? 18.95 : 18.75, a))
            ctx.stroke(l, ink, big ? 0.16 : 0.07, cap: .butt)
        }
        ctx.stroke(circle(.zero, 18.35), ink, 0.05)
        let romans = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
        for (i, s) in romans.enumerated() {
            // The conventional lower marker gives its solid chapter-ring position to the origin line.
            guard i != 6 else { continue }
            let a = 2 * π * Double(i) / 12
            drawText(ctx, s, font("Didot", 1.55), ink, at: pol(17.45, a), kern: -0.02, cw: a)
        }
        // The lower chapter-ring segment is the skeleton dial's only solid, uncluttered 6 o'clock surface.
        // Draw this last so the bridgework cannot obscure the dial-signature parody.
        drawText(ctx, "MAC MADE · HAND WOUND", font("AvenirNext-DemiBold", 0.76), ink, at: CGPoint(x: 0, y: -17.55), kern: 0.025)
        ctx.stroke(circle(.zero, 16.5), Col(1, 1, 1, 0.5), 0.06)
        // Logo metallised on the sapphire.
        drawText(ctx, "WOUND", font("Didot-Bold", 1.0), Col(1, 1, 1, 0.92), at: CGPoint(x: -8.4, y: -3.4), kern: 0.3)
        drawText(ctx, "SQUELETTE · 28 800 A/h", font("AvenirNext-DemiBold", 0.42), Col(1, 1, 1, 0.75), at: CGPoint(x: -8.4, y: -4.4), kern: 0.08)
        // Hands.
        let h = st.hours.truncatingRemainder(dividingBy: 12)
        drawHand(ctx, .zero, cw: 2 * π * h / 12, style: .skeletonBaton, length: 10.0, width: 1.15, tail: 2.2, metal: .rhodium, height: 0.55)
        drawHand(ctx, .zero, cw: 2 * π * (h * 60).truncatingRemainder(dividingBy: 60) / 60, style: .skeletonBaton, length: 15.2, width: 0.95, tail: 2.6, metal: .rhodium, height: 0.75)
        handCap(ctx, .zero, r: 0.85, metal: .rhodium)
    }
    drawCrystal(ctx, R: cs.bezelIn)
}

func drawReserveFan(_ ctx: CGContext, _ c: CGPoint, r: Double, reserve: Double, ink: Col, onDial: Bool = false) {
    let a0 = rad(-62), a1 = rad(62)
    let disc = sector(c, 0, r, a0 - 0.12, a1 + 0.12)
    if !onDial {
        ctx.scoped { ctx.shadow(0.1, -0.2, 0.4, Col(0, 0, 0, 0.6)); ctx.fill(disc, Col(0.05, 0.06, 0.08, 0.72)) }
        ctx.stroke(disc, Col(1, 1, 1, 0.25), 0.05)
    }
    for i in 0...20 {
        let a = lerp(a0, a1, Double(i) / 20)
        let big = i % 5 == 0
        let l = CGMutablePath(); l.move(to: pol(r * (big ? 0.66 : 0.75), a, c)); l.addLine(to: pol(r * 0.9, a, c))
        ctx.stroke(l, i < 3 ? Col(hex: 0xe23b3b) : ink, big ? 0.13 : 0.06, cap: .butt)
    }
    let f = font("AvenirNext-DemiBold", r * 0.17)
    drawText(ctx, "0", f, Col(hex: 0xe23b3b), at: pol(r * 0.5, a0 + 0.06, c))
    drawText(ctx, "40", f, ink, at: pol(r * 0.5, a1 - 0.05, c))
    drawText(ctx, "20", f, ink, at: pol(r * 0.5, 0, c))
    drawText(ctx, "RESERVE", font("AvenirNext-DemiBold", r * 0.12), ink.alpha(0.85), at: CGPoint(x: c.x, y: c.y - r * 0.28), kern: r * 0.02)
    let a = lerp(a0, a1, clamp(reserve))
    drawHand(ctx, c, cw: a, style: .needle, length: r * 0.86, width: r * 0.075, tail: r * 0.18, metal: reserve < 0.075 ? Metal(dark: Col(hex: 0x6a0b0b), mid: Col(hex: 0xc72a2a), light: Col(hex: 0xf06060), spec: Col(hex: 0xffc0c0)) : .blued, height: 0.3)
    handCap(ctx, c, r: r * 0.09, metal: .blued)
}

func drawSmallSeconds(_ ctx: CGContext, _ c: CGPoint, r: Double, seconds: Double) {
    ctx.fill(circle(c, r), Col(0.05, 0.06, 0.08, 0.55))
    ctx.stroke(circle(c, r), Col(1, 1, 1, 0.3), 0.05)
    for i in 0..<60 {
        let a = 2 * π * Double(i) / 60
        let big = i % 15 == 0, mid = i % 5 == 0
        let l = CGMutablePath(); l.move(to: pol(r * (big ? 0.7 : (mid ? 0.78 : 0.86)), a, c)); l.addLine(to: pol(r * 0.95, a, c))
        ctx.stroke(l, Col(1, 1, 1, 0.85), big ? 0.1 : 0.04, cap: .butt)
    }
    drawHand(ctx, c, cw: 2 * π * seconds / 60, style: .needle, length: r * 0.95, width: 0.16, tail: r * 0.3, metal: .blued, height: 0.35)
    handCap(ctx, c, r: 0.28, metal: .blued)
}
