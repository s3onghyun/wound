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
