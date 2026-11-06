import Foundation
import CoreGraphics

/// Instantaneous state of the simulated movement. Everything visual is derived from it.
struct MvState {
    var baseHours: Double = 10 + 9.6 / 60 // time shown when stopped (10:08:37)
    var baseSeconds: Double = 37
    var run: Double = 0          // seconds the going train has run
    var beats: Double = 0        // escape-wheel half-tooth steps (8 per second at 28,800 vph), fractional while dropping
    var bal: Double = 0          // balance angle (rad)
    var reserve: Double = 0      // 0...1 of 40 h
    var crown: Double = 0        // crown rotation (rad)
    var ratchet: Double = 0      // barrel arbor / ratchet rotation (rad)
    var rotor: Double = 0        // oscillating weight angle (rad)
    var reversers: Double = 0    // reversing-wheel angle (rad)
    var label: String = ""

    // Gear train (cw radians). Escape: 15 teeth, one half-tooth per beat.
    var escape: Double { -beats * 2 * π / 30 }
    var fourth: Double { beats * 2 * π / 30 / 16 }           // 1 rev/min: seconds
    var third: Double { -fourth / 7.5 }
    var center: Double { fourth / 60 }                       // 1 rev/h: minutes
    var barrel: Double { -center / 8 }
    var fork: Double { -rad(9) * tanh(bal / rad(14)) }
    var seconds: Double { baseSeconds + beats / 8 }           // seconds hand (s)
    var hours: Double { baseHours + run / 3600 }
    var cage: Double { 2 * π * (seconds / 60) }               // tourbillon: 1 rev/min
}

/// Skeleton movement layout (mm, dial side). Train computed from meshing distances.
struct SkelLayout {
    let barrel = CGPoint(x: 0, y: 8.3)
    let center = CGPoint.zero
    let third: CGPoint, fourth: CGPoint, escape: CGPoint, pallet: CGPoint, balance: CGPoint, crownWheel: CGPoint
    let barrelR = 7.15, centerR = 5.0, thirdR = 4.3, fourthR = 3.7, escapeR = 2.35, balanceR = 5.1, ratchetR = 3.7, crownWheelR = 2.1
    let forkDir: Double
    init() {
        third = pol(centerR + 0.65, rad(96))
        fourth = pol(thirdR + 0.55, rad(168), third)
        escape = pol(fourthR + 0.35, rad(218), fourth)
        balance = pol(7.45, rad(254), escape)
        forkDir = angleTo(escape, balance)
        pallet = pol(escapeR + 1.35, forkDir, escape)
        crownWheel = pol(ratchetR + crownWheelR + 0.15, rad(88), barrel)
    }
}
