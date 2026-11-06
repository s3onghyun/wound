import AppKit

@MainActor
final class SoundBank {
    private var lastTick = Date.distantPast

    func tick(muted: Bool) {
        guard !muted, Date().timeIntervalSince(lastTick) > 0.095 else { return }
        lastTick = Date()
        play("tick-8bps-1s")
    }

    func click(muted: Bool) { if !muted { play("crown-click") } }
    func rotor(muted: Bool) { if !muted { play("rotor-whirr-2s") } }

    private func play(_ name: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }
}
