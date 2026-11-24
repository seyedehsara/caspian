import SwiftUI

/// A trip from one country (or home) to another. Drives both the animation and the boarding pass.
struct Flight: Identifiable, Equatable {
    let id = UUID()
    let from: Country?
    let to: Country
    let date = Date()
}

/// A curved route that begins behind the globe and ends on the selected country,
/// which the globe has turned to face the viewer.
struct FlightRoute {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let globeCenter: CGPoint
    let globeRadius: CGFloat

    init(globeFrame: CGRect) {
        globeCenter = CGPoint(x: globeFrame.midX, y: globeFrame.midY)
        globeRadius = min(globeFrame.width, globeFrame.height) * 0.41

        // Start inside the globe silhouette so the plane can emerge from behind it.
        start = CGPoint(x: globeCenter.x + globeRadius * 0.28,
                        y: globeCenter.y - globeRadius * 0.28)
        control = CGPoint(x: globeCenter.x - globeRadius * 1.2,
                          y: globeCenter.y - globeRadius * 1.8)
        // Country selection rotates the destination to the middle of the globe.
        end = globeCenter
    }

    /// Position along the curve for t in 0...1 (quadratic Bézier).
    func point(at t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    /// Direction of travel at t, in radians, used to rotate the plane.
    func angle(at t: CGFloat) -> Angle {
        let u = 1 - t
        let dx = 2 * u * (control.x - start.x) + 2 * t * (end.x - control.x)
        let dy = 2 * u * (control.y - start.y) + 2 * t * (end.y - control.y)
        return .radians(Double(atan2(dy, dx)))
    }

    /// Hide the route until it first clears the globe's edge, then let it cross the front to land.
    var visibleRange: ClosedRange<CGFloat>? {
        var first: CGFloat?
        let samples = 240
        for index in 0...samples {
            let t = CGFloat(index) / CGFloat(samples)
            let point = self.point(at: t)
            let dx = point.x - globeCenter.x
            let dy = point.y - globeCenter.y
            if hypot(dx, dy) >= globeRadius * 1.015 {
                if first == nil { first = t }
            }
        }
        guard let first, first < 1 else { return nil }
        return first...1
    }
}

/// The dotted trail grows behind the plane, but remains hidden over the globe itself.
struct FlightTrail: Shape {
    var progress: CGFloat
    let globeFrame: CGRect

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let route = FlightRoute(globeFrame: globeFrame)
        guard let visibleRange = route.visibleRange,
              progress > visibleRange.lowerBound else { return Path() }

        let end = min(progress, visibleRange.upperBound)
        let segmentCount = max(2, Int((end - visibleRange.lowerBound) * 180))
        var path = Path()
        for step in 0...segmentCount {
            let fraction = CGFloat(step) / CGFloat(segmentCount)
            let t = visibleRange.lowerBound + (end - visibleRange.lowerBound) * fraction
            let point = route.point(at: t)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Moves and rotates the plane along the route. Animatable, so `withAnimation` interpolates it.
struct PlaneOnRoute: ViewModifier, Animatable {
    var progress: CGFloat
    let globeFrame: CGRect

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let route = FlightRoute(globeFrame: globeFrame)
        let point = route.point(at: progress)
        let emergeAt = route.visibleRange?.lowerBound ?? 0
        let emergence = min(1, max(0, (progress - emergeAt) / 0.06))
        let landing = min(1, max(0, (progress - 0.97) / 0.03))

        content
            .rotationEffect(route.angle(at: progress))
            .scaleEffect(1 - 0.6 * landing)
            .opacity(emergence * (1 - landing))
            .position(point)
    }
}

/// Everything drawn above the screen. The plane emerges from behind the globe, then flies
/// across its front and lands on the selected country at the centre.
struct FlightOverlay: View {
    var progress: CGFloat
    let globeFrame: CGRect

    var body: some View {
        GeometryReader { _ in
            ZStack {
                FlightTrail(progress: progress, globeFrame: globeFrame)
                    .stroke(Theme.yellow.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 9]))

                Image(systemName: "airplane")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .modifier(PlaneOnRoute(progress: progress, globeFrame: globeFrame))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
