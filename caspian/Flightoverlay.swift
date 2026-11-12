import SwiftUI

/// A trip from one country (or home) to another. Drives both the animation and the boarding pass.
struct Flight: Identifiable, Equatable {
    let id = UUID()
    let from: Country?
    let to: Country
    let date = Date()
}

/// The curved route from the bottom-left corner of the screen to the centre (where the globe
/// has turned the destination country to).
struct FlightRoute {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    init(in size: CGSize) {
        start = CGPoint(x: -30, y: size.height * 0.88)
        control = CGPoint(x: size.width * 0.12, y: size.height * 0.30)
        end = CGPoint(x: size.width / 2, y: size.height / 2)
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
}

/// The dotted trail. `progress` is animatable so the trail grows behind the plane.
struct FlightTrail: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let route = FlightRoute(in: rect.size)
        var p = Path()
        p.move(to: route.start)
        p.addQuadCurve(to: route.end, control: route.control)
        return p.trimmedPath(from: 0, to: progress)
    }
}

/// Moves and rotates the plane along the route. Animatable, so `withAnimation` interpolates it.
struct PlaneOnRoute: ViewModifier, Animatable {
    var progress: CGFloat
    let size: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let route = FlightRoute(in: size)
        let p = route.point(at: progress)
        // Fade and shrink the plane as it "lands" at the end of the route.
        let landing = max(0, (progress - 0.85) / 0.15)
        content
            .rotationEffect(route.angle(at: progress))
            .scaleEffect(1 - 0.6 * landing)
            .opacity(1 - landing)
            .position(p)
    }
}

/// Everything drawn on top of the globe while a flight is in progress.
struct FlightOverlay: View {
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FlightTrail(progress: progress)
                    .stroke(.white.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 9]))

                Image(systemName: "airplane")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .modifier(PlaneOnRoute(progress: progress, size: geo.size))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
