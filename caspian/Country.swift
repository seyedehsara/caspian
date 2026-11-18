import Foundation

/// A point on Earth. Longitude is east/west (-180...180), latitude is north/south (-90...90).
struct Coordinate: Hashable, Sendable {
    let lon: Double
    let lat: Double
}

/// A simple bounding box used to speed up "which country did I tap" lookups.
struct Bounds: Hashable, Sendable {
    var minLon = 180.0, minLat = 90.0, maxLon = -180.0, maxLat = -90.0

    mutating func include(_ c: Coordinate) {
        minLon = min(minLon, c.lon); maxLon = max(maxLon, c.lon)
        minLat = min(minLat, c.lat); maxLat = max(maxLat, c.lat)
    }

    func contains(lon: Double, lat: Double) -> Bool {
        lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat
    }
}

/// One country, with the shape of its borders.
/// `polygons` is a list of polygons; each polygon is a list of rings (first ring = outer edge, others = holes).
struct Country: Identifiable, Hashable, Sendable {
    let id: String            // ISO-style 3 letter code, e.g. "ITA"
    let name: String
    let iso2: String?         // 2 letter code, used for the flag emoji
    let continent: String
    let population: Int
    let polygons: [[[Coordinate]]]
    let bounds: Bounds

    /// Flag emoji built from the 2-letter code ("IT" -> 🇮🇹).
    var flag: String {
        guard let iso2, iso2.count == 2 else { return "🏳️" }
        return iso2.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }

    /// A point roughly in the middle of the country's biggest landmass. Used to aim the globe.
    var centroid: Coordinate {
        let rings = polygons.compactMap(\.first)
        guard let ring = rings.max(by: { $0.count < $1.count }), !ring.isEmpty else {
            return Coordinate(lon: 0, lat: 0)
        }
        let lon = ring.reduce(0.0) { $0 + $1.lon } / Double(ring.count)
        let lat = ring.reduce(0.0) { $0 + $1.lat } / Double(ring.count)
        return Coordinate(lon: lon, lat: lat)
    }

    /// True if the coordinate is inside this country.
    func contains(lon: Double, lat: Double) -> Bool {
        guard bounds.contains(lon: lon, lat: lat) else { return false }
        for rings in polygons {
            guard let outer = rings.first, Country.ring(outer, contains: lon, lat) else { continue }
            let inHole = rings.dropFirst().contains { Country.ring($0, contains: lon, lat) }
            if !inHole { return true }
        }
        return false
    }

    /// Classic ray-casting point-in-polygon test.
    private static func ring(_ ring: [Coordinate], contains lon: Double, _ lat: Double) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
            if (a.lat > lat) != (b.lat > lat) {
                let x = (b.lon - a.lon) * (lat - a.lat) / (b.lat - a.lat) + a.lon
                if lon < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    // Compare countries by id only, so we don't hash thousands of coordinates.
    static func == (lhs: Country, rhs: Country) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - GeoJSON decoding (matches the bundled countries.geojson)

struct GeoJSONCollection: Decodable {
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Decodable {
    let properties: Properties
    let geometry: Geometry

    struct Properties: Decodable {
        let id: String
        let name: String
        let iso2: String?
        let continent: String
        let population: Int
    }

    struct Geometry: Decodable {
        let polygons: [[[Coordinate]]]

        private enum CodingKeys: String, CodingKey { case type, coordinates }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            func ring(_ raw: [[Double]]) -> [Coordinate] {
                raw.map { Coordinate(lon: $0[0], lat: $0[1]) }
            }
            switch type {
            case "Polygon":
                let rings = try c.decode([[[Double]]].self, forKey: .coordinates)
                polygons = [rings.map(ring)]
            case "MultiPolygon":
                let polys = try c.decode([[[[Double]]]].self, forKey: .coordinates)
                polygons = polys.map { $0.map(ring) }
            default:
                polygons = []
            }
        }
    }

    var country: Country {
        var bounds = Bounds()
        for rings in geometry.polygons {
            for ring in rings {
                for c in ring { bounds.include(c) }
            }
        }
        return Country(
            id: properties.id,
            name: properties.name,
            iso2: properties.iso2,
            continent: properties.continent,
            population: properties.population,
            polygons: geometry.polygons,
            bounds: bounds
        )
    }
}
