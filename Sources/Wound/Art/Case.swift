import Foundation
import CoreGraphics

struct CaseStyle {
    var metal: Metal
    var R: Double = 21            // case radius (mm)
    var bezelIn: Double = 19.0    // opening radius
    var strap: Col = Col(hex: 0x2a1c14)
    var stitch: Col = Col(hex: 0xd8c7a6)
    var brushedFlank: Bool = false
}

func background(_ ctx: CGContext, _ w: Double, _ h: Double, top: Col = Col(hex: 0x2b2a2e), bottom: Col = Col(hex: 0x0d0d10)) {
    let r = CGRect(x: 0, y: 0, width: w, height: h)
    linFill(ctx, CGPath(rect: r, transform: nil), [(0, top), (1, bottom)], CGPoint(x: 0, y: h), CGPoint(x: 0, y: 0))
    radFill(ctx, CGPath(rect: r, transform: nil), [(0, Col(1, 1, 1, 0.06)), (1, Col(0, 0, 0, 0))],
            CGPoint(x: w * 0.4, y: h * 0.62), 0, CGPoint(x: w * 0.4, y: h * 0.62), max(w, h) * 0.6)
}

/// Strap, lugs, case band and bezel (everything under the dial). Crown is drawn separately.
func drawCaseUnder(_ ctx: CGContext, _ s: CaseStyle, back: Bool = false) {
    let R = s.R
    // Strap running off top and bottom.
    for dir in [1.0, -1.0] {
        let sw = R * 0.95
        let p = CGMutablePath()
        p.addRect(CGRect(x: -sw / 2, y: dir > 0 ? R * 0.6 : -R * 0.6 - 60, width: sw, height: 60))
        ctx.scoped { ctx.shadow(0.6, -1.2, 2.5, Col(0, 0, 0, 0.6)); ctx.fill(p, s.strap) }
        linFill(ctx, p, [(0, s.strap.scaled(0.55)), (0.18, s.strap.scaled(1.15)), (0.5, s.strap), (0.82, s.strap.scaled(1.1)), (1, s.strap.scaled(0.5))],
                CGPoint(x: -sw / 2, y: 0), CGPoint(x: sw / 2, y: 0))
        // Leather grain.
        var g = RNG(dir > 0 ? 11 : 12)
        ctx.scoped {
            ctx.clipPath(p)
            for _ in 0..<160 {
                let x = (g.next() - 0.5) * sw, y = dir * (R * 0.6 + g.next() * 40)
                ctx.fill(ellipse(CGPoint(x: x, y: y), 0.25 + g.next() * 0.4, 0.15 + g.next() * 0.25), Col(0, 0, 0, 0.12))
            }
        }
        // Stitching.
        for x in [-sw / 2 + 1.1, sw / 2 - 1.1] {
            let l = CGMutablePath(); l.move(to: CGPoint(x: x, y: dir * R * 0.75)); l.addLine(to: CGPoint(x: x, y: dir * (R * 0.75 + 60)))
            ctx.scoped {
                ctx.setLineDash(phase: 0, lengths: [0.9, 0.6])
                ctx.stroke(l, s.stitch.alpha(0.85), 0.22, cap: .butt)
            }
        }
    }
    // Lugs.
    for sy in [1.0, -1.0] {
        for sx in [1.0, -1.0] {
            let pts = [CGPoint(x: sx * R * 0.49, y: sy * R * 0.80), CGPoint(x: sx * R * 0.49, y: sy * (R + 3.0)), CGPoint(x: sx * R * 0.6, y: sy * (R + 3.6)),
                       CGPoint(x: sx * R * 0.7, y: sy * (R + 3.0)), CGPoint(x: sx * R * 0.8, y: sy * R * 0.66)]
            let lug = poly(smoothCurve(pts, samples: 8))
            ctx.scoped { ctx.shadow(0.5, -1.0, 1.6, Col(0, 0, 0, 0.7)); ctx.fill(lug, s.metal.dark) }
            linFill(ctx, lug, [(0, s.metal.dark), (0.3, s.metal.mid), (0.5, s.metal.spec), (0.62, s.metal.light), (1, s.metal.dark)],
                    CGPoint(x: sx * R * 0.49, y: 0), CGPoint(x: sx * R * 0.78, y: 0))
            // Polished bevel line along the top of the lug.
            let bev = poly([CGPoint(x: sx * R * 0.6, y: sy * R * 0.85), CGPoint(x: sx * R * 0.6, y: sy * (R + 3.2))], closed: false)
            ctx.stroke(bev, s.metal.spec.alpha(0.55), 0.35)
        }
    }
    // Case band.
    let band = circle(.zero, R)
    ctx.scoped { ctx.shadow(1.0, -2.0, 4.0, Col(0, 0, 0, 0.75)); ctx.fill(band, s.metal.dark) }
    conicFill(ctx, band, center: .zero, radius: R + 1, steps: 360, polish(s.metal, light: LIGHT, contrast: 1.1))
    if s.brushedFlank { circularGrain(ctx, clip: ring(.zero, s.bezelIn, R), center: .zero, r0: s.bezelIn, r1: R, step: 0.04, alpha: 0.25, eo: true) }
    // Bezel: polished bevel steps.
    ctx.stroke(circle(.zero, R - 0.05), s.metal.dark.alpha(0.9), 0.12)
    ctx.stroke(circle(.zero, R - 0.5), s.metal.spec.alpha(0.35), 0.08)
    let step = ring(.zero, s.bezelIn, s.bezelIn + 0.9)
    conicFill(ctx, step, center: .zero, radius: R, steps: 300, eo: true, polish(s.metal, light: LIGHT + π / 2, contrast: 1.3))
    ctx.stroke(circle(.zero, s.bezelIn), Col(0, 0, 0, 0.9), 0.18)
    _ = back
}

/// Knurled crown at 3 o'clock; `turn` is its rotation (radians), `out` the pulled-out distance.
func drawCrown(_ ctx: CGContext, _ s: CaseStyle, turn: Double, out: Double = 0, scale k: Double = 1) {
    let R = s.R, x0 = R - 0.6 + out, hh = 3.3 * k
    let tube = CGPath(roundedRect: CGRect(x: R - 1.2, y: -1.45, width: 2.2 + out, height: 2.9), cornerWidth: 0.3, cornerHeight: 0.3, transform: nil)
    linFill(ctx, tube, [(0, s.metal.dark), (0.35, s.metal.spec), (0.6, s.metal.mid), (1, s.metal.dark)], CGPoint(x: 0, y: 1.45), CGPoint(x: 0, y: -1.45))
    let body = CGPath(roundedRect: CGRect(x: x0 + 0.9, y: -hh, width: 3.4 * k, height: 2 * hh), cornerWidth: 0.9, cornerHeight: 0.9, transform: nil)
    ctx.scoped { ctx.shadow(0.4, -0.8, 1.2, Col(0, 0, 0, 0.7)); ctx.fill(body, s.metal.dark) }
    linFill(ctx, body, [(0, s.metal.dark), (0.2, s.metal.mid), (0.38, s.metal.spec), (0.55, s.metal.light), (0.85, s.metal.mid), (1, s.metal.dark)],
            CGPoint(x: 0, y: hh), CGPoint(x: 0, y: -hh))
    // Knurl grooves rotate with the crown: y = r·sin(θ), visible where facing us.
    let n = 30
    ctx.scoped {
        ctx.clipPath(body)
        for i in 0..<n {
            let th = 2 * π * Double(i) / Double(n) + turn
            let face = cos(th)
            guard face > 0.05 else { continue }
            let y = hh * 0.94 * sin(th)
            let l = CGMutablePath(); l.move(to: CGPoint(x: x0 + 1.25, y: y)); l.addLine(to: CGPoint(x: x0 + 0.9 + 3.4 * k - 0.65, y: y))
            ctx.stroke(l, Col(0, 0, 0, 0.55 * face), 0.2 * face + 0.03, cap: .butt)
            let l2 = CGMutablePath(); l2.move(to: CGPoint(x: x0 + 1.25, y: y + 0.12 * face)); l2.addLine(to: CGPoint(x: x0 + 0.9 + 3.4 * k - 0.65, y: y + 0.12 * face))
            ctx.stroke(l2, s.metal.spec.alpha(0.35 * face), 0.06, cap: .butt)
        }
    }
    // Polished end cap.
    let cap = CGPath(roundedRect: CGRect(x: x0 + 0.9 + 3.4 * k - 0.55, y: -hh + 0.2, width: 0.55, height: 2 * hh - 0.4), cornerWidth: 0.27, cornerHeight: 0.6, transform: nil)
    linFill(ctx, cap, [(0, s.metal.mid), (0.4, s.metal.spec), (1, s.metal.dark)], CGPoint(x: 0, y: hh), CGPoint(x: 0, y: -hh))
}

/// Sapphire crystal: inner edge shadow, broad reflection and a thin rim glint.
func drawCrystal(_ ctx: CGContext, R: Double, strength: Double = 1) {
    let c = circle(.zero, R)
    radFill(ctx, c, [(0, Col(0, 0, 0, 0)), (0.86, Col(0, 0, 0, 0)), (1, Col(0, 0, 0, 0.45 * strength))], .zero, 0, .zero, R)
    ctx.scoped {
        ctx.clipPath(c)
        var t = CGAffineTransform(rotationAngle: rad(28))
        let refl = CGPath(ellipseIn: CGRect(x: -R * 1.05, y: R * 0.05, width: R * 1.7, height: R * 1.15), transform: &t)
        linFill(ctx, refl, [(0, Col(1, 1, 1, 0.16 * strength)), (0.55, Col(1, 1, 1, 0.035 * strength)), (1, Col(1, 1, 1, 0))],
                CGPoint(x: -R * 0.5, y: R), CGPoint(x: R * 0.2, y: -R * 0.1))
        // Faint AR-coating bloom.
        radFill(ctx, c, [(0, Col(0.55, 0.45, 1, 0.07 * strength)), (1, Col(0.55, 0.45, 1, 0))], CGPoint(x: R * 0.55, y: -R * 0.5), 0, CGPoint(x: R * 0.55, y: -R * 0.5), R * 0.5)
    }
    ctx.stroke(arcPath(.zero, R * 0.975, rad(-75), rad(-10)), Col(1, 1, 1, 0.5 * strength), 0.22)
    ctx.stroke(arcPath(.zero, R * 0.975, rad(150), rad(195)), Col(1, 1, 1, 0.18 * strength), 0.14)
}

// MARK: - Callouts (detail labels for concept sheets)

struct Callout { var point: CGPoint; var label: String; var sub: String }

/// Draw callouts in pixel space; `toPx` maps watch mm to pixels. Labels stack on the left/right margins.
func drawCallouts(_ ctx: CGContext, _ items: [Callout], toPx: (CGPoint) -> CGPoint, leftX: Double, rightX: Double, top: Double, bottom: Double, fontScale: Double) {
    let left = items.filter { toPx($0.point).x < (leftX + rightX) / 2 }.sorted { toPx($0.point).y > toPx($1.point).y }
    let right = items.filter { toPx($0.point).x >= (leftX + rightX) / 2 }.sorted { toPx($0.point).y > toPx($1.point).y }
    let f1 = font("AppleSDGothicNeo-SemiBold", 30 * fontScale), f2 = font("AvenirNext-Medium", 22 * fontScale)
    let accent = Col(hex: 0xe8c27a)
    for (side, list) in [(0, left), (1, right)] {
        guard !list.isEmpty else { continue }
        let gapY = (top - bottom) / Double(list.count)
        for (i, it) in list.enumerated() {
            let p = toPx(it.point)
            let ly = top - gapY * (Double(i) + 0.5)
            let lx = side == 0 ? leftX : rightX
            let elbowX = side == 0 ? lx + 30 * fontScale : lx - 30 * fontScale
            let path = poly([p, CGPoint(x: elbowX, y: ly), CGPoint(x: lx, y: ly)], closed: false)
            ctx.stroke(path, Col(0, 0, 0, 0.6), 4 * fontScale)
            ctx.stroke(path, accent.alpha(0.85), 1.8 * fontScale)
            ctx.fill(circle(p, 7 * fontScale), Col(0, 0, 0, 0.6))
            ctx.fill(circle(p, 4.5 * fontScale), accent)
            let tx = side == 0 ? lx - 12 * fontScale : lx + 12 * fontScale
            drawText(ctx, it.label, f1, Col(hex: 0xf3efe6), at: CGPoint(x: tx, y: ly + 14 * fontScale), align: side == 0 ? .right : .left)
            drawText(ctx, it.sub, f2, Col(hex: 0xa9a49a), at: CGPoint(x: tx, y: ly - 22 * fontScale), align: side == 0 ? .right : .left)
        }
    }
}
