import AppKit

@MainActor
final class SoundBank {
    private var lastTick = Date.distantPast
    private lazy var sounds: Bundle? = {
        let bundle = SoundResources.bundle()
        if bundle == nil { NSLog("Wound: %@ not found; sound stays off", SoundResources.bundleName) }
        return bundle
    }()

    func tick(muted: Bool) {
        guard !muted, Date().timeIntervalSince(lastTick) > 0.095 else { return }
        lastTick = Date()
        play(SoundResources.tick)
    }

    func click(muted: Bool) { if !muted { play(SoundResources.click) } }
    func rotor(muted: Bool) { if !muted { play(SoundResources.rotor) } }

    private func play(_ name: String) {
        guard let url = sounds?.url(forResource: name, withExtension: "wav") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }
}

/// Finds SwiftPM's resource bundle without `Bundle.module`, whose generated accessor checks only the app
/// root and this machine's build directory, then traps. scripts/bundle.sh puts the bundle in
/// Contents/Resources, so a released app must look there; a missing bundle means silence, not a crash.
enum SoundResources {
    static let bundleName = "Wound_Wound.bundle"
    static let tick = "tick-8bps-1s"
    static let click = "crown-click"
    static let rotor = "rotor-whirr-2s"
    static let all = [tick, click, rotor]

    static func bundle(in main: Bundle = .main) -> Bundle? {
        // Contents/Resources inside Wound.app; the binary's own directory under `swift run`.
        for case let directory? in [main.resourceURL, main.bundleURL] {
            if let bundle = Bundle(url: directory.appendingPathComponent(bundleName)) { return bundle }
        }
        return nil
    }
}
