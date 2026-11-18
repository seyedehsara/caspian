import RealityKit
import simd

/// Builds a sphere whose texture mapping we control exactly:
/// u (0...1) goes from longitude -180 to +180, v goes from the north pole to the south pole.
/// Because we build it ourselves, converting a tapped 3D point back to lat/lon is simple
/// (see `GlobeMesh.latLon(for:)`).
enum GlobeMesh {
    /// Set to false if the map ever appears upside down on your device.
    static let flipV = true

    static func make(radius: Float = 1, segments: Int = 128, rings: Int = 64) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for r in 0...rings {
            let v = Float(r) / Float(rings)            // 0 = north pole, 1 = south pole
            let lat = (0.5 - v) * .pi                  // +90° ... -90° in radians
            for s in 0...segments {
                let u = Float(s) / Float(segments)     // 0 = -180°, 1 = +180°
                let lon = (u - 0.5) * 2 * .pi
                let n = SIMD3<Float>(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
                positions.append(n * radius)
                normals.append(n)
                uvs.append(SIMD2<Float>(u, flipV ? 1 - v : v))
            }
        }

        let stride = UInt32(segments + 1)
        for r in 0..<rings {
            for s in 0..<segments {
                let a = UInt32(r) * stride + UInt32(s)
                let b = a + stride
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }

        var descriptor = MeshDescriptor(name: "globe")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// Converts a point on the sphere (in the globe entity's own coordinate space) to degrees.
    static func latLon(for localPoint: SIMD3<Float>) -> (lat: Double, lon: Double) {
        let p = simd_normalize(localPoint)
        let lat = Double(asin(max(-1, min(1, p.y)))) * 180 / .pi
        let lon = Double(atan2(p.x, p.z)) * 180 / .pi
        return (lat, lon)
    }
}
