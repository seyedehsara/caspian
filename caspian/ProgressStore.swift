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
    /// Postage stamp ids bought with points, in the order they were bought.
    private(set) var ownedStamps: [String] { didSet { defaults.set(ownedStamps, forKey: "ownedStamps") } }

    init() {
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        points = defaults.integer(forKey: "points")
        playerName = defaults.string(forKey: "playerName") ?? "Traveler"
        discovered = defaults.stringArray(forKey: "discovered") ?? []
        ownedStamps = defaults.stringArray(forKey: "ownedStamps") ?? []
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

    // MARK: Postage stamps

    func owns(_ stamp: PostageStamp) -> Bool { ownedStamps.contains(stamp.id) }

    func canAfford(_ stamp: PostageStamp) -> Bool { points >= stamp.price }

    /// Spends points on a stamp. Returns false if it is already owned or the points are not enough.
    @discardableResult
    func buy(_ stamp: PostageStamp) -> Bool {
        guard !owns(stamp), canAfford(stamp) else { return false }
        points -= stamp.price
        ownedStamps.append(stamp.id)
        return true
    }

    func reset() {
        points = 0
        discovered = []
        ownedStamps = []
    }
}
