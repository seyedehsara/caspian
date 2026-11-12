import Foundation
import Observation

/// What the player has achieved. Saved in UserDefaults so it survives relaunches.
@Observable
@MainActor
final class ProgressStore {
    private let defaults = UserDefaults.standard

    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") } }
    var points: Int { didSet { defaults.set(points, forKey: "points") } }
    var playerName: String { didSet { defaults.set(playerName, forKey: "playerName") } }
    /// Country ids in the order they were unlocked.
    private(set) var discovered: [String] { didSet { defaults.set(discovered, forKey: "discovered") } }

    init() {
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        points = defaults.integer(forKey: "points")
        playerName = defaults.string(forKey: "playerName") ?? "Traveler"
        discovered = defaults.stringArray(forKey: "discovered") ?? []
    }

    var discoveredIDs: Set<String> { Set(discovered) }

    func isDiscovered(_ countryID: String) -> Bool { discovered.contains(countryID) }

    func addPoints(_ amount: Int) { points += amount }

    /// Unlocks a country. Returns true if it was new.
    @discardableResult
    func unlock(_ countryID: String) -> Bool {
        guard !discovered.contains(countryID) else { return false }
        discovered.append(countryID)
        return true
    }

    func reset() {
        points = 0
        discovered = []
    }
}
