import Foundation
import Observation

/// Loads the bundled countries.geojson once and answers "which country is at this lat/lon?".
@Observable
@MainActor
final class CountryStore {
    private(set) var countries: [Country] = []
    private(set) var isLoaded = false
    private(set) var loadError: String?

    func load() async {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson") else {
            loadError = "countries.geojson is missing from the app bundle."
            return
        }
        do {
            // Decode off the main thread, it's ~200 KB of coordinates.
            let decoded = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(GeoJSONCollection.self, from: data)
            }.value
            countries = decoded.features.map(\.country).sorted { $0.name < $1.name }
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func country(atLat lat: Double, lon: Double) -> Country? {
        countries.first { $0.contains(lon: lon, lat: lat) }
    }
}
