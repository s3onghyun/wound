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

@MainActor @Test func otherAppsKeystrokesAreNeverMonitored() {
    #expect(!MovementController.globalActivityEvents.contains(.keyDown))
    #expect(MovementController.globalActivityEvents.contains(.mouseMoved))
    #expect(MovementController.localActivityEvents.contains(.keyDown)) // Wound's own window may still count typing
}

private let repoResources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Resources")

private func strings(_ language: String) throws -> [String: String] {
    let url = repoResources.appendingPathComponent("\(language).lproj/Localizable.strings")
    return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(language).lproj")
}

/// Format specifiers of a localized string, positions dropped: "%1$@ %lld" -> ["%@", "%lld"].
private func specifiers(_ text: String) -> [String] {
    text.matches(of: #/%(?:\d+\$)?(@|lld)/#).map { "%\($0.output.1)" }.sorted()
}

@Test func koreanCoversEveryEnglishStringWithTheSameArguments() throws {
    let english = try strings("en"), korean = try strings("ko")
    #expect(Set(english.keys) == Set(korean.keys))
    for (key, value) in english {
        #expect(value == key, "en value differs from its key: \(key)")
        #expect(specifiers(korean[key] ?? "") == specifiers(key), "\(key)")
        #expect(korean[key] != key, "untranslated: \(key)")
    }
    for step in explainSteps {
        #expect(korean[step.title] != nil, "\(step.title)")
    }
}

@Test func storeBuildDeclaresSandboxOnlyAndNoCollectedData() throws {
    let entitlements = try #require(NSDictionary(contentsOf: repoResources.appendingPathComponent("MAS/Wound.entitlements")) as? [String: Any])
    #expect(entitlements.keys.sorted() == ["com.apple.security.app-sandbox"])
    #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)

    let manifest = try #require(NSDictionary(contentsOf: repoResources.appendingPathComponent("MAS/PrivacyInfo.xcprivacy")) as? [String: Any])
    #expect(manifest["NSPrivacyTracking"] as? Bool == false)
    #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    #expect(apis.map { $0["NSPrivacyAccessedAPIType"] as? String } == ["NSPrivacyAccessedAPICategoryUserDefaults"])
    #expect(apis.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
}

@Test func privacyManifestListsEveryRequiredReasonAPI() throws {
    // Apple's required-reason APIs other than UserDefaults; using one means adding it to PrivacyInfo.xcprivacy.
    let undeclared = ["systemUptime", "mach_absolute_time", "creationDate", "modificationDate", "contentModificationDate",
                      "fileModificationDate", "attributesOfItem", "getattrlist", "volumeAvailableCapacity",
                      "systemFreeSize", "systemSize", "statfs", "activeInputModes"]
    let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Sources/Wound")
    let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
    for case let file as URL in files where file.pathExtension == "swift" {
        let code = try String(contentsOf: file, encoding: .utf8)
        for api in undeclared {
            #expect(!code.contains(api), "\(file.lastPathComponent) uses \(api)")
        }
    }
}

@Test func storeTextFitsAppStoreConnectLimits() throws {
    let metadata = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../appstore/metadata")
    func text(_ path: String) throws -> String { try String(contentsOf: metadata.appendingPathComponent(path), encoding: .utf8) }
    // App Store Connect limits: characters, except keywords and review notes, which are bytes.
    for locale in ["en-US", "ko"] {
        let name = try text("\(locale)/name.txt")
        #expect((2...30).contains(name.count), "\(locale) name")
        #expect(try text("\(locale)/subtitle.txt").count <= 30, "\(locale) subtitle")
        #expect(try text("\(locale)/promotional_text.txt").count <= 170, "\(locale) promotional text")
        #expect(try text("\(locale)/description.txt").count <= 4000, "\(locale) description")
        let keywords = try text("\(locale)/keywords.txt")
        #expect(keywords.utf8.count <= 100, "\(locale) keywords")
        #expect(!keywords.contains(", "), "\(locale) keywords are comma separated without spaces")
    }
    #expect(try text("review_information/notes.txt").utf8.count <= 4000)
    // Store text describes the store app only: no other distribution channels or signing caveats.
    for path in ["en-US/description.txt", "en-US/promotional_text.txt", "ko/description.txt", "ko/promotional_text.txt", "review_information/notes.txt"] {
        let body = try text(path).lowercased()
        for word in ["github", "homebrew", "notariz", "open source", "open-source"] {
            #expect(!body.contains(word), "\(path) mentions \(word)")
        }
    }
}
