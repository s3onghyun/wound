import Foundation
import Testing
@testable import Wound

@Test func movementModel() throws {
    try MovementModelChecks.run()
}

@Test func explainCaptionNumbersComeFromTheTrain() {
    #expect(abs(rpm { $0.fourth } - 1) < 1e-9)          // small seconds: once a minute
    #expect(abs(rpm { $0.center } - 1.0 / 60) < 1e-9)   // minute hand: once an hour
    #expect(abs(rpm { $0.escape } - 16) < 1e-9)
    #expect(abs(1 / rpm { $0.barrel } / 60 - 8) < 1e-9) // barrel drum: once every 8 h
    #expect(reservePerCrownTurn() == 15 * 60)
}

@Test func explainTourCoversThePowerPath() {
    #expect(explainSteps.map(\.title) == ["Crown", "Ratchet & click", "Mainspring barrel", "Going train", "Escape wheel",
                                          "Pallet fork", "Balance & hairspring", "Hands", "Automatic rotor"])
    #expect(explainSteps.filter(\.back).map(\.title) == ["Automatic rotor"])
    for step in explainSteps {
        #expect(!step.spots(MvState()).isEmpty)
        #expect(!step.caption(MvState()).isEmpty)
    }
}

// Mirrors scripts/bundle.sh: Wound.app/Contents/Resources/Wound_Wound.bundle holding the package's wav files.
private func packagedApp(withSounds: Bool) throws -> URL {
    let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Sources/Wound")
    let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Wound.app")
    let resources = app.appendingPathComponent("Contents/Resources")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try Data(#"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>test.wound</string></dict></plist>"#.utf8)
        .write(to: app.appendingPathComponent("Contents/Info.plist"))
    if withSounds {
        let bundle = resources.appendingPathComponent(SoundResources.bundleName)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        for name in SoundResources.all {
            try FileManager.default.copyItem(at: sources.appendingPathComponent("\(name).wav"), to: bundle.appendingPathComponent("\(name).wav"))
        }
    }
    return app
}

@Test func soundsResolveFromThePackagedApp() throws {
    let main = try #require(Bundle(url: packagedApp(withSounds: true)))
    let sounds = try #require(SoundResources.bundle(in: main))
    for name in SoundResources.all {
        #expect(sounds.url(forResource: name, withExtension: "wav") != nil, "\(name).wav")
    }
}

@Test func missingSoundBundleIsSilentNotFatal() throws {
    let main = try #require(Bundle(url: packagedApp(withSounds: false)))
    #expect(SoundResources.bundle(in: main) == nil)
}

@Test func shippedCodeNeverCallsBundleModule() throws {
    // Bundle.module traps when the build directory is gone, as it is on every user's Mac.
    let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Sources/Wound")
    let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
    for case let file as URL in files where file.pathExtension == "swift" {
        let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(!code.contains { $0.contains("Bundle.module") }, "\(file.lastPathComponent)")
    }
}
