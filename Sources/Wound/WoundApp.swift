import AppKit
import SwiftUI

struct WoundApp: App {
    @StateObject private var movement = MovementController()

    var body: some Scene {
        WindowGroup("Wound") {
            WoundView()
                .environmentObject(movement)
                .frame(minWidth: 460, minHeight: 640)
                .onChange(of: movement.alwaysOnTop) { _, _ in movement.applyWindowLevel() }
                .task { movement.applyWindowLevel() }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Wound · \(movement.reserveLabel)", systemImage: movement.running ? "gearshape.2" : "gearshape") {
            Text(movement.running ? "\(movement.reserveLabel) remaining" : "Unwound")
            Button("Show Wound") { NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Toggle("Automatic winding", isOn: $movement.automatic)
            Button("Quit Wound") { NSApp.terminate(nil) }
        }

        Settings {
            SettingsView().environmentObject(movement)
        }
    }
}

private struct WoundView: View {
    @EnvironmentObject private var movement: MovementController

    var body: some View {
        VStack(spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WOUND").font(.system(size: 15, weight: .bold, design: .serif)).tracking(4)
                    Text("CAL. W-28S · 23 JEWELS · AUTOMATIQUE").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    movement.explaining.toggle()
                } label: {
                    Label(movement.explaining ? "Done" : "Explain", systemImage: "scope")
                }
                Button {
                    movement.toggleBack()
                } label: {
                    Label(movement.backShown ? "Dial" : "Caseback", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(movement.explaining)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, 26)
            .padding(.top, 21)

            ZStack(alignment: .trailing) {
                MovementRenderView(movement: movement)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 22)
                CrownInteractionView(movement: movement)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 22)
                    .accessibilityLabel("Winding crown")
                    .accessibilityHint("Scroll over the crown or drag it upward to wind the watch")
            }
            .frame(maxHeight: 400)
            .clipped()

            if movement.explaining { ExplainPanel() }

            VStack(spacing: 7) {
                HStack {
                    Text("POWER RESERVE")
                    Spacer()
                    Text(movement.reserveLabel).monospacedDigit()
                }
                ProgressView(value: movement.reserveFraction)
                    .tint(movement.running ? Color(red: 0.82, green: 0.54, blue: 0.16) : .red)
                Text(!movement.running ? "UNWOUND · SCROLL THE CROWN TO START" : movement.explaining ? "SLOW MOTION · TRAIN AT 1/20 SPEED" : "ESCAPEMENT RUNNING · 8 BEATS / SEC")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(movement.running ? Color.secondary : Color.red)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 30)

            HStack(spacing: 14) {
                Toggle("Automatic", isOn: $movement.automatic)
                Toggle("Sound", isOn: Binding(get: { !movement.muted }, set: { movement.muted = !$0 }))
                Spacer()
                Button("Stop") { movement.exhaustForDemo() }
                Button("Reset") { movement.resetDemo() }
            }
            .font(.system(size: 11, weight: .medium))
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// One station of the explain tour: which part is lit, what it does, and the controls to move along.
private struct ExplainPanel: View {
    @EnvironmentObject private var movement: MovementController

    var body: some View {
        let step = movement.explainCurrent
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text("\(movement.explainStep + 1)/\(explainSteps.count) · \(step.title.uppercased())")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.91, green: 0.76, blue: 0.48))
                Spacer()
                Toggle("Lift bridges", isOn: $movement.bridgesLifted)
                    .toggleStyle(.switch)
                    .disabled(step.back)
                Button { movement.stepExplain(-1) } label: { Label("Previous part", systemImage: "chevron.left").labelStyle(.iconOnly) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button { movement.stepExplain(1) } label: { Label("Next part", systemImage: "chevron.right").labelStyle(.iconOnly) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .font(.system(size: 11, weight: .medium))
            .controlSize(.small)
            Text(step.caption(movement.renderState()))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
        }
        .padding(.horizontal, 30)
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var movement: MovementController

    var body: some View {
        Form {
            Toggle("Sound", isOn: Binding(get: { !movement.muted }, set: { movement.muted = !$0 }))
            Toggle("Automatic winding from activity", isOn: $movement.automatic)
            Toggle("Always on top", isOn: $movement.alwaysOnTop)
            Picker("Demo speed", selection: $movement.demoSpeed) {
                Text("Real time").tag(1.0)
                Text("60×").tag(60.0)
                Text("600×").tag(600.0)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 190)
        .padding()
    }
}

private struct MovementRenderView: NSViewRepresentable {
    let movement: MovementController

    func makeNSView(context: Context) -> WatchNSView { WatchNSView(movement: movement) }
    func updateNSView(_ view: WatchNSView, context: Context) { view.movement = movement; view.needsDisplay = true }
}

private final class WatchNSView: NSView {
    var movement: MovementController

    init(movement: MovementController) { self.movement = movement; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.scoped {
            context.clip(to: bounds)
            let side = min(bounds.width, bounds.height)
            background(context, Double(bounds.width), Double(bounds.height), top: Col(hex: 0x1c1d21), bottom: Col(hex: 0x090a0d))
            inWatch(context, center: CGPoint(x: bounds.midX, y: bounds.midY), scale: side / 56) {
                let state = movement.renderState()
                if movement.showsBack {
                    drawBack(context, state, style: .skeleton, cs: skelCase)
                } else {
                    drawSkeletonFront(context, state, lift: movement.lift)
                }
                if movement.explaining { drawSpotlight(context, movement.explainCurrent.spots(state)) }
            }
        }
    }
}

private struct CrownInteractionView: NSViewRepresentable {
    let movement: MovementController
    func makeNSView(context: Context) -> CrownNSView { CrownNSView(movement: movement) }
    func updateNSView(_ view: CrownNSView, context: Context) { view.movement = movement }
}

private final class CrownNSView: NSView {
    var movement: MovementController
    private var lastY: CGFloat?

    init(movement: MovementController) { self.movement = movement; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard onCrown(event) else { return }
        movement.wind(turns: max(0, Double(event.scrollingDeltaY)) / 8)
    }

    override func mouseDown(with event: NSEvent) { lastY = convert(event.locationInWindow, from: nil).y }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard onCrown(event), let oldY = lastY else { return }
        movement.wind(turns: max(0, Double(point.y - oldY)) / 12)
        lastY = point.y
    }
    override func mouseUp(with event: NSEvent) { lastY = nil }

    private func onCrown(_ event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        return point.x > bounds.width * 0.80 && abs(point.y - bounds.midY) < bounds.height * 0.16
    }
}
