import AppKit
import Combine
import SwiftUI

@MainActor
final class MovementController: ObservableObject {
    @Published private(set) var stored: StoredMovement
    @Published private(set) var balancePhase = 0.0
    @Published private(set) var crownTurns = 0.0
    @Published private(set) var rotorTurns = 0.0
    @Published private(set) var backShown = false
    @Published private(set) var overWinding = false
    @Published var explaining = false
    @Published private(set) var explainStep = 0
    @Published var bridgesLifted = false
    @Published private(set) var lift = 0.0
    @AppStorage("automatic") var automatic = true
    // Sound is opt-in: a running desktop watch should not begin ticking unprompted.
    @AppStorage("muted") var muted = true
    @AppStorage("alwaysOnTop") var alwaysOnTop = false
    @AppStorage("demoSpeed") var demoSpeed = 1.0

    private static let storageKey = "wound.movement.v1"
    private var lastDate: Date
    private var tickAccumulator = 0.0
    private var lastFallbackActivity = false
    private var observers: [Any] = []
    private let sounds = SoundBank()

    init(now: Date = .now, defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey), let decoded = try? JSONDecoder().decode(StoredMovement.self, from: data) {
            stored = decoded
        } else {
            stored = .fresh(at: now)
        }
        lastDate = now
        stored.advance(to: now, speed: 1)
        installActivityMonitors()
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
    }

    var running: Bool { stored.running }
    var reserveFraction: Double { stored.reserveFraction }
    var reserveLabel: String { String(format: "%.1f h", stored.reserve / 3600) }
    var displayDate: Date { Date(timeIntervalSinceReferenceDate: stored.displaySeconds) }

    func advance(now: Date = .now) {
        let wallDelta = max(0, now.timeIntervalSince(lastDate))
        lastDate = now
        let wasRunning = stored.running
        stored.advance(to: now, speed: demoSpeed)
        if wasRunning {
            // Explaining slows only the drawn train; reserve and displayed time stay real.
            let motion = wallDelta * (explaining ? explainSlowdown : 1)
            balancePhase += motion * 8 * .pi * 2
            tickAccumulator += motion * 8
            while tickAccumulator >= 1 {
                tickAccumulator -= 1
                sounds.tick(muted: muted)
            }
        }
        lift += ((explaining && bridgesLifted ? 1 : 0) - lift) * min(1, wallDelta * 6)
        automaticFallback()
        persist()
    }

    func wind(turns: Double) {
        let resisted = stored.wind(turns: turns)
        crownTurns += turns * .pi * 2
        overWinding = resisted
        sounds.click(muted: muted)
        if resisted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.overWinding = false }
        }
        persist()
    }

    func registerActivity() {
        guard automatic else { return }
        stored.automaticWind(activitySeconds: 3)
        rotorTurns += .pi / 4
        sounds.rotor(muted: muted)
        persist()
    }

    func toggleBack() { backShown.toggle() }
    var explainCurrent: ExplainStep { explainSteps[explainStep] }
    var showsBack: Bool { explaining ? explainCurrent.back : backShown }
    func stepExplain(_ delta: Int) { explainStep = (explainStep + delta + explainSteps.count) % explainSteps.count }
    func exhaustForDemo() { stored.reserve = 0; persist() }
    func resetDemo() { stored = .fresh(at: .now); persist() }

    func renderState() -> MvState {
        var state = MvState()
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: displayDate)
        state.baseHours = Double((components.hour ?? 0) % 12) + Double(components.minute ?? 0) / 60 + Double(components.second ?? 0) / 3600
        state.baseSeconds = Double(components.second ?? 0)
        state.reserve = reserveFraction
        state.run = 0
        state.beats = running ? balancePhase / (.pi * 2) : 0
        state.bal = running ? sin(balancePhase) * rad(14) : 0
        state.crown = crownTurns
        state.ratchet = crownTurns
        state.rotor = rotorTurns
        state.reversers = rotorTurns * 1.7
        return state
    }

    func applyWindowLevel() {
        NSApp.windows.first(where: { $0.title == "Wound" })?.level = alwaysOnTop ? .floating : .normal
    }

    private func installActivityMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .scrollWheel, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            Task { @MainActor in self?.registerActivity() }
        }) { observers.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in self?.registerActivity() }
            return event
        }) { observers.append(local) }
    }

    private func automaticFallback() {
        guard automatic else { return }
        let active = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null) < 0.25
        if active && !lastFallbackActivity { registerActivity() }
        lastFallbackActivity = active
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
