import Foundation

struct StoredMovement: Codable, Equatable {
    var reserve: TimeInterval
    var displaySeconds: TimeInterval
    var savedAt: Date

    static let fullReserve: TimeInterval = 40 * 60 * 60

    static func fresh(at date: Date) -> StoredMovement {
        StoredMovement(reserve: 8 * 60 * 60, displaySeconds: date.timeIntervalSinceReferenceDate, savedAt: date)
    }

    mutating func advance(to date: Date, speed: Double) {
        let wallDelta = max(0, date.timeIntervalSince(savedAt))
        savedAt = date
        guard reserve > 0 else { return }
        let movementDelta = wallDelta * max(0, speed)
        let consumed = min(reserve, movementDelta)
        reserve -= consumed
        displaySeconds += consumed
    }

    mutating func wind(turns: Double) -> Bool {
        guard turns > 0 else { return false }
        let wasFull = reserve >= Self.fullReserve - 0.1
        reserve = min(Self.fullReserve, reserve + turns * 15 * 60)
        return wasFull
    }

    mutating func automaticWind(activitySeconds: TimeInterval) {
        guard activitySeconds > 0, reserve < Self.fullReserve else { return }
        reserve = min(Self.fullReserve, reserve + activitySeconds * 3)
    }

    var reserveFraction: Double { min(1, max(0, reserve / Self.fullReserve)) }
    var running: Bool { reserve > 0 }
}
