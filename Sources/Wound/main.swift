import Foundation
import SwiftUI

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

if CommandLine.arguments.contains("--self-test") {
    do {
        try MovementModelChecks.run()
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else if let index = CommandLine.arguments.firstIndex(of: "--render-demo"), CommandLine.arguments.indices.contains(index + 1) {
    renderDemo(to: CommandLine.arguments[index + 1])
} else {
    WoundApp.main()
}
