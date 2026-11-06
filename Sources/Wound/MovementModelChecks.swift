import Foundation

enum MovementModelChecks {
    static func run() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var drained = StoredMovement(reserve: 20, displaySeconds: 100, savedAt: start)
        drained.advance(to: start.addingTimeInterval(30), speed: 1)
        try expect(drained.reserve == 0 && drained.displaySeconds == 120, "drain reaches zero and freezes displayed time")
        drained.advance(to: start.addingTimeInterval(60), speed: 1)
        try expect(drained.displaySeconds == 120, "stopped movement remains frozen")

        var wound = StoredMovement(reserve: StoredMovement.fullReserve - 10, displaySeconds: 0, savedAt: start)
        try expect(wound.wind(turns: 1) == false && wound.reserve == StoredMovement.fullReserve, "wind saturates at full reserve")
        try expect(wound.wind(turns: 1) == true && wound.reserve == StoredMovement.fullReserve, "full barrel reports resistance")

        var automatic = StoredMovement(reserve: StoredMovement.fullReserve - 2, displaySeconds: 0, savedAt: start)
        automatic.automaticWind(activitySeconds: 10)
        try expect(automatic.reserve == StoredMovement.fullReserve, "automatic winding is capped")

        let original = StoredMovement(reserve: 4321, displaySeconds: 9876, savedAt: Date(timeIntervalSinceReferenceDate: 123))
        let persisted = try JSONDecoder().decode(StoredMovement.self, from: JSONEncoder().encode(original))
        try expect(persisted == original, "persistence round trip")
    }

    private static func expect(_ condition: Bool, _ name: String) throws {
        guard condition else { throw CheckFailure(name: name) }
        print("PASS: \(name)")
    }
}

private struct CheckFailure: Error, LocalizedError {
    let name: String
    var errorDescription: String? { "FAIL: \(name)" }
}
