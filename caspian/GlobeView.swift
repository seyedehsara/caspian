import SwiftUI
import RealityKit

/// Keeps references to the RealityKit objects between SwiftUI updates.
/// Not @Observable on purpose: changing these must not trigger a SwiftUI redraw.
@MainActor
final class GlobeHolder {
    var globe: ModelEntity?

    // Current rotation of the globe, in radians.
    var yaw: Float = 0.35      // start roughly on Europe/Africa
    var pitch: Float = -0.25
    var dragAnchor: (yaw: Float, pitch: Float)?

    private var hasApplied = false
    private var lastApplied: String?
    private var lastDiscovered: Set<String> = []
    private var renderTask: Task<Void, Never>?

    var orientation: simd_quatf {
        simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    /// Applies the rotation immediately (used while dragging).
    func applyRotation() {
        globe?.orientation = orientation
    }

    /// Smoothly turns the globe so the given coordinate faces the viewer.
    func turn(to coordinate: Coordinate, duration: TimeInterval) {
        guard let globe else { return }
        let targetYaw = -Float(coordinate.lon) * .pi / 180
        let targetPitch = Float(coordinate.lat) * .pi / 180

        // Take the shortest way round instead of spinning the long way.
        var delta = targetYaw - yaw
        delta = atan2(sin(delta), cos(delta))
        yaw += delta
        pitch = targetPitch

        globe.stopAllAnimations()
        let target = Transform(scale: .one, rotation: orientation, translation: .zero)
        if duration <= 0 {
            globe.transform = target
        } else {
            globe.move(to: target,
                       relativeTo: globe.parent,
                       duration: duration,
                       timingFunction: .easeInOut)
        }
    }

    /// Repaints the globe texture when the selected country changes.
    func applySelection(_ id: String?, discovered: Set<String>, countries: [Country], renderer: GlobeTextureRenderer) {
        if hasApplied && id == lastApplied && discovered == lastDiscovered { return }
        hasApplied = true
        lastApplied = id
        lastDiscovered = discovered
        renderTask?.cancel()
        renderTask = Task { [weak self] in
            let image = await Task.detached(priority: .userInitiated) {
                renderer.render(countries: countries, selectedID: id, discoveredIDs: discovered)
            }.value
            guard !Task.isCancelled, let image,
                  let texture = try? await TextureResource(image: image, options: .init(semantic: .color))
            else { return }
            self?.globe?.model?.materials = [UnlitMaterial(texture: texture)]
        }
    }
}

struct GlobeView: View {
    @Environment(CountryStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selected: Country?
    var discovered: Set<String> = []

    /// Country previews finish sooner; the plane keeps its own, separate flight timing.
    static let turnDuration: TimeInterval = 1.25
    static let flightDuration: TimeInterval = 1.6

    @State private var holder = GlobeHolder()
    private let renderer = GlobeTextureRenderer()

    var body: some View {
        RealityView { content in
            let globe = ModelEntity()
            globe.name = "globe"
            if let mesh = try? GlobeMesh.make() {
                globe.model = ModelComponent(mesh: mesh, materials: [UnlitMaterial(color: .gray)])
            }
            // These two components are what make the entity tappable.
            globe.components.set(CollisionComponent(shapes: [.generateSphere(radius: 1)]))
            globe.components.set(InputTargetComponent())
            globe.orientation = holder.orientation
            content.add(globe)
            holder.globe = globe

            #if !os(visionOS)
            // On iPhone, iPad and Mac we need our own camera. visionOS uses the real one.
            // .virtual stops iOS from showing the device camera feed behind the globe (AR mode).
            content.camera = .virtual
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 3.0]
            content.add(camera)
            #endif

            holder.applySelection(selected?.id, discovered: discovered, countries: store.countries, renderer: renderer)
        } update: { _ in
            holder.applySelection(selected?.id, discovered: discovered, countries: store.countries, renderer: renderer)
        }
        .gesture(tap)
        .gesture(drag)
        // Turn towards the selection however it was made: a tap, a chip, or the end of a quiz.
        .onChange(of: selected) { _, country in
            guard let country else { return }
            holder.turn(to: country.centroid, duration: reduceMotion ? 0 : Self.turnDuration)
        }
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel("Interactive globe")
        .accessibilityHint("Drag to rotate, or tap a country to select it")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if holder.dragAnchor == nil {
                    holder.globe?.stopAllAnimations()
                    holder.dragAnchor = (holder.yaw, holder.pitch)
                }
                guard let anchor = holder.dragAnchor else { return }
                let sensitivity: Float = 0.006
                holder.yaw = anchor.yaw + Float(value.translation.width) * sensitivity
                holder.pitch = max(-1.3, min(1.3, anchor.pitch + Float(value.translation.height) * sensitivity))
                holder.applyRotation()
            }
            .onEnded { _ in holder.dragAnchor = nil }
    }

    private var tap: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                // Find the 3D point that was tapped, then express it in the globe's own space
                // so the current rotation is already accounted for.
                #if os(visionOS)
                let local = value.convert(value.location3D, from: .local, to: value.entity)
                #else
                guard let hit = value.hitTest(point: value.location, in: .local).first else { return }
                let local = value.entity.convert(position: hit.position, from: nil)
                #endif
                let (lat, lon) = GlobeMesh.latLon(for: local)
                let country = store.country(atLat: lat, lon: lon)
                let wasAlreadySelected = country?.id == selected?.id
                selected = country
                // A repeated tap doesn't change the binding, but can still re-aim after a drag.
                if wasAlreadySelected, let country {
                    holder.turn(to: country.centroid, duration: reduceMotion ? 0 : Self.turnDuration)
                }
            }
    }
}
