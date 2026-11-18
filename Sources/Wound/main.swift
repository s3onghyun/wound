import CoreText
import Foundation
import SwiftUI

// The Mac App Store build (scripts/bundle-mas.sh, -D MAS) has no command-line modes: App Review
// guideline 2.5.19 rejects undocumented features, and a sandboxed app cannot write to arbitrary paths.
#if MAS
WoundApp.main()
#else
func renderDemo(to directory: String) {
    let fileManager = FileManager.default
    try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let frames = 240
    for frame in 0..<frames {
        let time = Double(frame) / 10
        var state = MvState()
        let winding = min(1, max(0, (time - 3) / 5))
        state.reserve = time < 3 ? 0 : min(0.84, 0.08 + winding * 0.76)
        state.run = max(0, time - 8) * 8
        state.beats = state.run * 8
        state.bal = sin(state.beats * .pi) * rad(14)
        state.crown = winding * .pi * 10
        state.ratchet = state.crown
        state.rotor = max(0, sin(time * 2) * 0.8 + (time > 15 ? time : 0))
        state.reversers = state.rotor * 1.7
        let context = makeContext(720, 720)
        background(context, 720, 720, top: Col(hex: 0x1c1d21), bottom: Col(hex: 0x090a0d))
        inWatch(context, center: CGPoint(x: 360, y: 360), scale: 720 / 56) {
            if time > 16 && time < 21 {
                drawBack(context, state, style: .skeleton, cs: skelCase)
            } else {
                drawSkeletonFront(context, state)
            }
        }
        savePNG(context, "\(directory)/frame-\(String(format: "%04d", frame)).png")
    }
}

/// Explain-mode reel: each station of the tour for 3.2 s, slow motion, with its caption set below the watch.
func renderExplain(to directory: String) {
    try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let perStep = 32, width = 720, height = 860
    for (index, step) in explainSteps.enumerated() {
        for f in 0..<perStep {
            let t = Double(f) / 10, time = Double(index * perStep + f) / 10
            var state = MvState()
            state.reserve = 0.62
            state.beats = time * MvState.beatsPerSecond * explainSlowdown * 4 // 1/5 speed so a 3 s station shows motion
            state.bal = sin(state.beats * π) * rad(14)
            state.crown = index == 0 ? t * π : 0
            state.ratchet = state.crown
            state.rotor = step.back ? sin(t * 1.6) * 0.9 : 0
            state.reversers = state.rotor * 1.7
            let context = makeContext(width, height)
            background(context, Double(width), Double(height), top: Col(hex: 0x1c1d21), bottom: Col(hex: 0x090a0d))
            inWatch(context, center: CGPoint(x: 360, y: Double(height) - 360), scale: 720 / 56) {
                if step.back {
                    drawBack(context, state, style: .skeleton, cs: skelCase)
                } else {
                    drawSkeletonFront(context, state, lift: index == 3 ? smooth((t - 0.6) / 1.2) : 0)
                }
                drawSpotlight(context, step.spots(state), k: smooth(t / 0.5))
            }
            drawText(context, "\(index + 1)/\(explainSteps.count) · \(step.title.uppercased())", font("Menlo-Bold", 17), Col(hex: 0xe8c27a), at: CGPoint(x: 40, y: 112), align: .left, kern: 1)
            let caption = NSAttributedString(string: step.caption(state), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font("AvenirNext-Medium", 19),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): Col(hex: 0xe6e2da).cg,
            ])
            let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(caption), CFRange(), CGPath(rect: CGRect(x: 40, y: 18, width: 640, height: 76), transform: nil), nil)
            CTFrameDraw(frame, context)
            savePNG(context, "\(directory)/frame-\(String(format: "%04d", index * perStep + f)).png")
        }
    }
}

/// 1024 px app icon: the running skeleton movement on a dark plate inset to the macOS icon grid
/// (824 px rounded square, 100 px margin), so the system shadow and mask line up with other apps.
func renderIcon(to path: String) {
    let size = 1024.0, inset = 100.0
    let plate = CGPath(roundedRect: CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
                       cornerWidth: 185, cornerHeight: 185, transform: nil)
    var state = MvState()
    state.baseHours = 10 + 10 / 60
    state.baseSeconds = 30
    state.reserve = 0.8
    state.beats = 3
    state.bal = rad(10)
    let context = makeContext(Int(size), Int(size))
    context.scoped {
        context.clipPath(plate)
        background(context, size, size, top: Col(hex: 0x2a2b31), bottom: Col(hex: 0x08090c))
        inWatch(context, center: CGPoint(x: size / 2 - 12, y: size / 2), scale: 824 / 58) {
            drawSkeletonFront(context, state)
        }
    }
    context.stroke(plate, Col(1, 1, 1, 0.08), 2)
    savePNG(context, path)
}

if CommandLine.arguments.contains("--self-test") {
    do {
        try MovementModelChecks.run()
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else if let index = CommandLine.arguments.firstIndex(of: "--render-demo"), CommandLine.arguments.indices.contains(index + 1) {
    renderDemo(to: CommandLine.arguments[index + 1])
} else if let index = CommandLine.arguments.firstIndex(of: "--render-explain"), CommandLine.arguments.indices.contains(index + 1) {
    renderExplain(to: CommandLine.arguments[index + 1])
} else if let index = CommandLine.arguments.firstIndex(of: "--render-icon"), CommandLine.arguments.indices.contains(index + 1) {
    renderIcon(to: CommandLine.arguments[index + 1])
} else {
    WoundApp.main()
}
#endif
