import Foundation
import CoreGraphics

// "Explain the movement": a guided tour along the power path, in the style of the Anatomy skill
// (github.com/wheresryan22/anatomy): the object is the explanation, so the tour lights the real
// drawn part instead of floating labels, and every number in a caption comes from the same model
// that moves the parts.

/// Slow motion used while explaining: the going train runs at a twentieth of real speed.
let explainSlowdown = 1.0 / 20

/// Revolutions per minute of a train angle, measured by running the model for one minute of beats.
func rpm(_ angle: (MvState) -> Double) -> Double {
    var minute = MvState()
    minute.beats = MvState.beatsPerSecond * 60
    return abs(angle(minute) - angle(MvState())) / (2 * π)
}

/// Reserve one full crown turn stores, read from the winding model (seconds).
func reservePerCrownTurn() -> TimeInterval {
    var empty = StoredMovement(reserve: 0, displaySeconds: 0, savedAt: .distantPast)
    _ = empty.wind(turns: 1)
    return empty.reserve
}

struct ExplainStep: Sendable {
    let title: String
    let caption: @Sendable (MvState) -> String
    /// Spotlit regions in watch millimetres (dial side unless `back`).
    let spots: @Sendable (MvState) -> [(CGPoint, Double)]
    var back = false
}

/// Fixed-point number for a caption; captions interpolate it so the localized key keeps a plain %@.
private func num(_ x: Double, _ digits: Int = 0) -> String { String(format: "%.\(digits)f", x) }

// Titles and captions are localized from Contents/Resources/<lang>.lproj/Localizable.strings
// (Resources/ in the repo); keys are the English text with %@ / %lld for the interpolated values.
let explainSteps: [ExplainStep] = {
    let L = SkelLayout()
    let crown = CGPoint(x: skelCase.R + 2, y: 0)
    return [
        ExplainStep(title: String(localized: "Crown"),
                    caption: { _ in String(localized: "Winding the crown turns the crown wheel, which turns the ratchet. One full turn stores \(Int(reservePerCrownTurn() / 60)) min.") },
                    spots: { _ in [(crown, 3.9), (L.crownWheel, L.crownWheelR + 0.5)] }),
        ExplainStep(title: String(localized: "Ratchet & click"),
                    caption: { _ in String(localized: "The ratchet sits on the barrel arbor. The click drops into each tooth so the spring cannot unwind back through the crown.") },
                    spots: { _ in [(L.barrel, L.ratchetR + 2.2)] }),
        ExplainStep(title: String(localized: "Mainspring barrel"),
                    caption: { st in String(localized: "The coiled mainspring holds \(num(StoredMovement.fullReserve / 3600)) h, \(num(st.reserve * StoredMovement.fullReserve / 3600, 1)) h right now. Its toothed drum turns once every \(num(1 / rpm { $0.barrel } / 60)) h and drives the train.") },
                    spots: { _ in [(L.barrel, L.barrelR + 0.4)] }),
        ExplainStep(title: String(localized: "Going train"),
                    caption: { _ in String(localized: "Centre, third and fourth wheels gear the spring down: the centre wheel turns once every \(num(1 / rpm { $0.center })) min, the fourth once every \(num(60 / rpm { $0.fourth })) s.") },
                    spots: { _ in [(L.center, L.centerR + 0.3), (L.third, L.thirdR + 0.3), (L.fourth, L.fourthR + 0.3)] }),
        ExplainStep(title: String(localized: "Escape wheel"),
                    caption: { _ in String(localized: "The escape wheel would spin freely, but it may only advance half a tooth per beat: \(num(rpm { $0.escape })) turns a minute.") },
                    spots: { _ in [(L.escape, L.escapeR + 0.6)] }),
        ExplainStep(title: String(localized: "Pallet fork"),
                    caption: { _ in String(localized: "Two ruby pallets lock and release the escape wheel \(num(MvState.beatsPerSecond)) times a second, kicking the balance at each release.") },
                    spots: { _ in [(L.pallet, 2.2), (L.escape, L.escapeR + 0.4)] }),
        ExplainStep(title: String(localized: "Balance & hairspring"),
                    caption: { _ in String(localized: "The balance swings against its hairspring. This is the timekeeper: \(num(MvState.beatsPerSecond)) beats a second, \((MvState.beatsPerSecond * 3600).formatted()) an hour.") },
                    spots: { _ in [(L.balance, L.balanceR + 0.5)] }),
        ExplainStep(title: String(localized: "Hands"),
                    caption: { _ in String(localized: "The centre wheel carries the minute hand, the motion works divide it by 12 for the hour hand, and the fourth wheel carries the small seconds.") },
                    spots: { _ in [(L.center, 2.4), (L.fourth, 2.9)] }),
        ExplainStep(title: String(localized: "Automatic rotor"),
                    caption: { _ in String(localized: "On the back, the oscillating weight swings with motion (here, your mouse and keyboard). Reversing wheels turn both directions into winding.") },
                    spots: { st in [(pol(14, st.rotor), 4.4), (pol(4.5, rad(62)), 1.9), (pol(6.6, rad(78)), 2.1), (.zero, 2.8)] },
                    back: true),
    ]
}()

/// Dim everything except the spotlit parts, rimmed in the callout accent. `k` fades it in (0...1).
func drawSpotlight(_ ctx: CGContext, _ spots: [(CGPoint, Double)], k: Double = 1) {
    guard k > 0, !spots.isEmpty else { return }
    let holes = spots.dropFirst().reduce(circle(spots[0].0, spots[0].1)) { $0.union(circle($1.0, $1.1)) }
    let veil = CGPath(rect: CGRect(x: -40, y: -40, width: 80, height: 80), transform: nil).subtracting(holes)
    ctx.fill(veil, Col(0.02, 0.02, 0.03, 0.68 * k))
    ctx.stroke(holes, Col(hex: 0xe8c27a, 0.85 * k), 0.12)
}
