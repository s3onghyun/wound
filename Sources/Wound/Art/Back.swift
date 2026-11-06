import Foundation
import CoreGraphics

enum BackStyle { case skeleton, dress }

@inline(__always) func mir(_ p: CGPoint) -> CGPoint { CGPoint(x: -p.x, y: p.y) }
func mirPath(_ p: CGPath) -> CGPath { var t = CGAffineTransform(scaleX: -1, y: 1); return p.copy(using: &t)! }

/// Ball-bearing rotor hub.
func rotorBearing(_ ctx: CGContext, rot: Double, metal: Metal) {
    let c = CGPoint.zero
    conicFill(ctx, circle(c, 2.5), center: c, radius: 3, steps: 90, polish(.steel, light: LIGHT, contrast: 1.2))
    ctx.fill(circle(c, 2.0), Col(0.05, 0.05, 0.06))
    for i in 0..<11 {
        let p = pol(1.62, rot * 0.5 + 2 * π * Double(i) / 11, c)
        radFill(ctx, circle(p, 0.3), [(0, Col.white), (0.3, Metal.steel.light), (1, Metal.steel.dark)], pol(0.12, LIGHT, p), 0, p, 0.3)
    }
    let inner = circle(c, 1.25)
    conicFill(ctx, inner, center: c, radius: 1.5, steps: 72, polish(metal, light: LIGHT, contrast: 1.2))
    for i in 0..<3 { screw(ctx, pol(0.7, rot + 2 * π * Double(i) / 3, c), 0.26, slot: rot + Double(i)) }
}

/// Oscillating weight. `rot` = cw angle of its heavy side as seen from the back.
func drawRotor(_ ctx: CGContext, rot: Double, style: BackStyle, R: Double) {
    let a0 = rot - π / 2, a1 = rot + π / 2
    let metal: Metal = style == .dress ? .rose : .gold
    var shape = CGMutablePath()
    if style == .dress {
        shape = sector(.zero, 2.2, R, a0, a1, n: 90)
    } else {
        shape.addPath(sector(.zero, R - 2.6, R, a0, a1, n: 90))
        for k in [-1.0, 0, 1] {
            let a = rot + k * rad(58)
            let arm = poly(smoothCurve([pol(1.8, a - 0.5, .zero), pol(R * 0.5, a - 0.12, .zero), pol(R - 2.4, a + 0.12, .zero)], samples: 10), closed: false)
            shape.addPath(arm.copy(strokingWithWidth: 0.85, lineCap: .round, lineJoin: .round, miterLimit: 2))
        }
        shape.addPath(circle(.zero, 2.6))
    }
    ctx.scoped { ctx.shadow(0.6, -1.0, 1.6, Col(0, 0, 0, 0.8)); ctx.fill(shape, metal.dark) }
    conicFill(ctx, shape, center: .zero, radius: R + 1, steps: 300, polish(metal, light: LIGHT, contrast: 0.8))
    if style == .dress {
        // Côtes circulaires on the rotor face.
        ctx.scoped {
            ctx.clipPath(shape)
            var r = 3.0
            while r < R - 0.6 {
                ctx.stroke(circle(.zero, r), metal.spec.alpha(0.28), 0.42)
                ctx.stroke(circle(.zero, r + 0.42), metal.dark.alpha(0.22), 0.3)
                r += 1.15
            }
        }
        arcText(ctx, "WOUND · AUTOMATIQUE", font("Didot-Bold", 1.05), metal.dark.alpha(0.85), center: .zero, radius: R - 1.6, mid: rot, kern: 0.12)
        arcText(ctx, "WOUND · AUTOMATIQUE", font("Didot-Bold", 1.05), metal.spec.alpha(0.5), center: CGPoint(x: -0.04, y: 0.05), radius: R - 1.6, mid: rot, kern: 0.12)
    } else {
        // Heavy segment engraved with its job.
        arcText(ctx, "OSCILLATING WEIGHT", font("AvenirNext-DemiBold", 0.8), metal.dark.alpha(0.9), center: .zero, radius: R - 1.45, mid: rot, kern: 0.25)
    }
    ctx.scoped { ctx.clipPath(shape); ctx.stroke(shape, metal.spec.alpha(0.7), 0.3) }
    rotorBearing(ctx, rot: rot, metal: metal)
}

func drawCasebackRing(_ ctx: CGContext, _ cs: CaseStyle, win: Double, text: (String, String)) {
    let rp = ring(.zero, win, cs.R - 0.6)
    conicFill(ctx, rp, center: .zero, radius: cs.R, steps: 300, eo: true, polish(cs.metal, light: LIGHT, contrast: 0.7))
    circularGrain(ctx, clip: rp, center: .zero, r0: win, r1: cs.R, step: 0.04, alpha: 0.28, eo: true)
    ctx.stroke(circle(.zero, cs.R - 0.6), cs.metal.spec.alpha(0.6), 0.12)
    let rt = (win + cs.R - 0.6) / 2
    let f = font("AvenirNext-DemiBold", 0.78)
    for (dx, dy, c) in [(0.03, -0.04, cs.metal.spec.alpha(0.6)), (0.0, 0.0, cs.metal.dark.alpha(0.9))] {
        arcText(ctx, text.0, f, c, center: CGPoint(x: dx, y: dy), radius: rt, mid: 0, kern: 0.18)
        arcText(ctx, text.1, f, c, center: CGPoint(x: dx, y: dy), radius: rt + 0.6, mid: π, bottom: true, kern: 0.18)
    }
    for k in 0..<4 {
        let a = [rad(68), rad(112), rad(248), rad(292)][k]
        screw(ctx, pol(rt + 0.15, a), 0.55, slot: a * 2.3, metal: cs.metal)
    }
    // Inner bevel into the sapphire window.
    ctx.stroke(circle(.zero, win), Col(0, 0, 0, 0.8), 0.25)
    ctx.stroke(circle(.zero, win + 0.25), cs.metal.spec.alpha(0.5), 0.1)
}

func drawBack(_ ctx: CGContext, _ st: MvState, style: BackStyle, cs: CaseStyle) {
    ctx.scoped { ctx.scaleBy(x: -1, y: 1); drawCaseUnder(ctx, cs, back: true); drawCrown(ctx, cs, turn: -st.crown) }
    let win = cs.R - 4.6
    let L = SkelLayout()
    ctx.scoped {
        ctx.clipPath(circle(.zero, win + 0.1))
        if style == .skeleton {
            radFill(ctx, circle(.zero, win), [(0, Col(hex: 0x2a2c31)), (1, Col(hex: 0x0a0b0d))], CGPoint(x: 3, y: 4), 0, .zero, win)
            // The chapter ring's underside, seen through the openwork.
            ctx.stroke(circle(.zero, 17.2), Col(hex: 0x6b6862), 1.2)
            drawBarrel(ctx, mir(L.barrel), R: L.barrelR, drum: -st.barrel, arbor: -st.ratchet, wound: st.reserve)
            drawWheel(ctx, mir(L.center), WheelSpec(teeth: 80, r: L.centerR, spokes: 5, curve: -0.55, spokeW: 0.38, hubR: 1.0), rot: -st.center)
            drawWheel(ctx, mir(L.third), WheelSpec(teeth: 75, r: L.thirdR, spokes: 5, curve: 0.5, spokeW: 0.34, hubR: 0.8, pinionLeaves: 10, pinionR: 0.55), rot: -st.third)
            drawWheel(ctx, mir(L.fourth), WheelSpec(teeth: 80, r: L.fourthR, spokes: 4, curve: -0.5, spokeW: 0.32, hubR: 0.7, pinionLeaves: 10, pinionR: 0.5), rot: -st.fourth)
            escapeWheel(ctx, mir(L.escape), R: L.escapeR, rot: -st.escape)
            for (i, b) in skelBridges(L).enumerated() { drawBridge(ctx, mirPath(b), metal: .rhodium, finish: .cotes, stripeAngle: rad(20), eo: i == 0) }
            for p in [L.third, L.fourth, L.escape, L.pallet, L.barrel] { jewel(ctx, mir(p), 0.36) }
            for (a, r) in [(-68.0, 16.0), (68, 16), (84, 16), (162, 16), (172, 16), (236, 16), (188, 16), (-112, 16)] {
                screw(ctx, mir(pol(r - 0.05, rad(a))), 0.48, slot: rad(a * 2.1))
            }
            palletFork(ctx, pivot: mir(L.pallet), dir: -L.forkDir, length: dist(L.pallet, L.balance) - 1.0, span: L.escapeR * 0.95, rock: -st.fork)
            balanceWheel(ctx, mir(L.balance), R: L.balanceR, rot: -st.bal, metal: .gold, arms: 3, screws: 18)
            hairspring(ctx, mir(L.balance), r0: 0.95, r1: 3.6, turns: 12, bal: -st.bal, stud: rad(-40))
            jewel(ctx, mir(L.balance), 0.42)
        } else {
            drawDressMovement(ctx, st, L)
        }
        // Automatic module: reversing wheels then the rotor.
        for (p, r, k) in [(pol(4.5, rad(62)), 1.55, 1.0), (pol(6.6, rad(78)), 1.75, -0.8)] {
            drawWheel(ctx, p, WheelSpec(teeth: 28, r: r, metal: .gilt, spokes: 4, curve: 0.4, spokeW: 0.25, rimW: 0.3, hubR: 0.4), rot: st.reversers * k)
        }
        drawRotor(ctx, rot: st.rotor, style: style, R: win - 0.2)
    }
    drawCasebackRing(ctx, cs, win: win, text: style == .dress ? ("WOUND · CAL. W-28 · 21 RUBIS · AUTOMATIQUE", "SAPPHIRE · 28 800 A/h · RÉSERVE 40 H · Nº 001")
                                                         : ("WOUND SQUELETTE · CAL. W-28S · 23 RUBIS", "MAC MADE · HAND WOUND"))
    ctx.scoped { ctx.clipPath(circle(.zero, win)); drawCrystal(ctx, R: win, strength: 0.8) }
}

/// Finished three-quarter-plate movement (concept B caseback): Côtes de Genève, gold chatons, blued screws.
func drawDressMovement(_ ctx: CGContext, _ st: MvState, _ L: SkelLayout) {
    let win = 16.4
    let base = circle(.zero, win)
    // Bottom plate seen in the openings: perlage.
    ctx.fill(base, Metal.rhodium.mid)
    ctx.scoped {
        ctx.clipPath(base)
        var row = 0
        var y = -win
        while y < win {
            var x = -win + (row % 2 == 0 ? 0 : 0.55)
            while x < win {
                let p = CGPoint(x: x, y: y)
                radFill(ctx, circle(p, 0.62), [(0, Metal.rhodium.spec), (0.5, Metal.rhodium.light), (1, Metal.rhodium.dark)], pol(0.25, LIGHT, p), 0, p, 0.66)
                x += 1.1
            }
            y += 0.95; row += 1
        }
    }
    let bal = mir(L.balance), esc = mir(L.escape), pal = mir(L.pallet)
    escapeWheel(ctx, esc, R: L.escapeR, rot: -st.escape)
    palletFork(ctx, pivot: pal, dir: -L.forkDir, length: dist(L.pallet, L.balance) - 1.0, span: L.escapeR * 0.95, rock: -st.fork)
    // Three-quarter plate with openings for the balance and escapement.
    let plate = CGMutablePath()
    plate.addPath(circle(.zero, win))
    plate.addPath(circle(bal, L.balanceR + 0.7))
    plate.addPath(band([esc, pal, pol(1.5, angleTo(pal, bal), pal)], width: 5.4))
    let barrelBridge = CGMutablePath(); barrelBridge.addPath(circle(mir(L.barrel), 8.2))
    drawBridge(ctx, plate, metal: .rhodium, finish: .cotes, stripeAngle: rad(28), eo: true)
    drawBridge(ctx, barrelBridge, metal: .rhodium, finish: .cotes, stripeAngle: rad(28))
    // Gold-filled engraving.
    for (dx, c) in [(0.04, Col(0, 0, 0, 0.6)), (0.0, Metal.gold.light)] {
        drawText(ctx, "WOUND", font("Didot-Bold", 1.5), c, at: CGPoint(x: 7.4 + dx, y: -1.0 - dx), kern: 0.4)
        drawText(ctx, "TWENTY-ONE  21  JEWELS", font("AvenirNext-DemiBold", 0.55), c, at: CGPoint(x: 7.4 + dx, y: -2.3 - dx), kern: 0.12)
        drawText(ctx, "UNADJUSTED · SWISS LEVER", font("AvenirNext-DemiBold", 0.45), c, at: CGPoint(x: 7.4 + dx, y: -3.1 - dx), kern: 0.1)
    }
    // Screwed gold chatons.
    for p in [mir(L.third), mir(L.fourth), esc, pal, mir(L.center)] {
        jewel(ctx, p, 0.42)
        for k in 0..<3 { screw(ctx, pol(1.35, rad(20) + 2 * π * Double(k) / 3, p), 0.26, slot: Double(k) * 1.3) }
    }
    for a in [rad(-40), rad(60), rad(150), rad(250), rad(-100), rad(20)] { screw(ctx, pol(13.9, a), 0.6, slot: a * 3) }
    // Crown wheel and ratchet (soleil finish).
    let cw = mir(L.crownWheel)
    drawRatchet(ctx, mir(L.barrel), r: 4.9, rot: -st.ratchet, clickAt: rad(40), openwork: false)
    drawWheel(ctx, cw, WheelSpec(teeth: 32, r: L.crownWheelR, metal: .steel, spokes: 0, jewel: false), rot: st.ratchet * 4.9 / L.crownWheelR)
    sunburst(ctx, clip: circle(cw, L.crownWheelR - 0.3), center: cw, r: L.crownWheelR, count: 120, alpha: 0.3)
    screw(ctx, cw, 0.7, slot: st.ratchet * 2)
    // Balance and the engraved cock with swan-neck regulator.
    balanceWheel(ctx, bal, R: L.balanceR, rot: -st.bal, metal: .gold, arms: 2, screws: 16)
    hairspring(ctx, bal, r0: 0.95, r1: 3.6, turns: 12, bal: -st.bal, stud: rad(-40))
    let foot = pol(15.2, angleTo(.zero, bal) + 0.25)
    let cock = CGMutablePath()
    cock.addPath(poly(smoothCurve([pol(2.4, angleTo(bal, foot) - 1.2, foot), pol(1.0, angleTo(bal, foot) - 1.5, bal), pol(1.6, angleTo(bal, foot) + π, bal),
                                   pol(1.0, angleTo(bal, foot) + 1.5, bal), pol(2.4, angleTo(bal, foot) + 1.2, foot)], samples: 10)))
    cock.addPath(circle(bal, 1.6))
    drawBridge(ctx, cock, metal: .rhodium, finish: .frosted)
    // Hand-engraved scroll on the cock.
    ctx.scoped {
        ctx.clipPath(cock)
        for k in 0..<5 {
            let s = Double(k) * 0.9
            let p = poly(smoothCurve([pol(2.6 + s, angleTo(bal, foot) - 0.6, bal), pol(3.2 + s, angleTo(bal, foot), bal), pol(2.6 + s, angleTo(bal, foot) + 0.6, bal)], samples: 8), closed: false)
            ctx.stroke(p, Col(0, 0, 0, 0.3), 0.12)
            ctx.stroke(p, Col(1, 1, 1, 0.35), 0.05)
        }
    }
    let swan = poly(smoothCurve([pol(2.0, angleTo(bal, foot) + 0.7, bal), pol(3.6, angleTo(bal, foot) + 0.55, bal), pol(4.6, angleTo(bal, foot) + 0.25, bal), pol(4.0, angleTo(bal, foot) + 0.05, bal)], samples: 10), closed: false)
    ctx.stroke(swan, Metal.blued.dark, 0.28)
    ctx.stroke(swan, Metal.blued.light, 0.1)
    let idx = band([bal, pol(4.2, angleTo(bal, foot) - 0.35, bal)], width: 0.3)
    drawBridge(ctx, idx, metal: .steel)
    drawText(ctx, "−     +", font("AvenirNext-Bold", 0.5), Col(0, 0, 0, 0.6), at: pol(4.9, angleTo(bal, foot) - 0.32, bal), cw: angleTo(bal, foot) - 0.32 - π / 2)
    jewel(ctx, bal, 0.45)
    screw(ctx, pol(1.6, angleTo(bal, foot) + 0.0, foot), 0.55, slot: 0.8)
}
