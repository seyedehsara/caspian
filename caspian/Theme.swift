import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// All the colours and styles in one place, so the whole app stays consistent.
/// Built on the Caspian palette: blue #5A7EB1, yellow #F0C745, terracotta #C85E3F, teal #74A7A1.
/// Each colour has a job. Blue speaks (buttons, titles, the ocean), yellow rewards (points,
/// unlocked countries), terracotta points (selection, mistakes), teal confirms (correct answers).
/// Every colour has a light and a dark version (HIG: support both appearances).
enum Theme {
    // The four palette colours
    static let blue       = Color(hex: 0x5A7EB1)
    static let yellow     = Color(hex: 0xF0C745)
    static let terracotta = Color(hex: 0xC85E3F)
    static let teal       = Color(hex: 0x74A7A1)

    // Roles
    static let primary   = Color(light: blue, dark: Color(hex: 0x8DA8D2))
    static let ink       = Color(light: Color(hex: 0x2B3A52), dark: Color(hex: 0xEEF1F6))   // blue pushed to near-black
    static let cream     = Color(light: Color(hex: 0xFBF8F5), dark: Color(hex: 0x141A26))
    static let card      = Color(light: .white, dark: Color(hex: 0x1F2838))
    static let success   = teal
    static let danger    = terracotta
    static let gold      = yellow

    // Pale washes, one per palette colour, used behind screens and in gradients
    static let sky       = Color(light: Color(hex: 0xC4CDDA), dark: Color(hex: 0x27364E))   // pale blue
    static let lavender  = Color(light: Color(hex: 0xF7EBBA), dark: Color(hex: 0x3B3420))   // pale yellow (quiz)
    static let mint      = Color(light: Color(hex: 0xD0E4E1), dark: Color(hex: 0x1C3331))   // pale teal (correct, collection)
    static let blush     = Color(light: Color(hex: 0xEAD3C9), dark: Color(hex: 0x3A2520))   // pale terracotta (wrong, profile)

    /// Soft gradients used behind illustrations, each a tint of one palette colour.
    static let tints: [[Color]] = [
        [Color(hex: 0xC4CDDA), Color(hex: 0xDDE3EA)],   // blue
        [Color(hex: 0xEAD3C9), Color(hex: 0xF3E6DF)],   // terracotta
        [Color(hex: 0xD0E4E1), Color(hex: 0xE4EFED)],   // teal
        [Color(hex: 0xDDE3EA), Color(hex: 0xE4EFED)],   // blue into teal
        [Color(hex: 0xF7EBBA), Color(hex: 0xFCF5E0)],   // yellow
    ]

    // Night sky behind the globe: the teal pushed deep, with a soft teal glow in the middle.
    static let nightTop    = Color(hex: 0x0A191B)
    static let nightBottom = Color(hex: 0x173836)
    static let nightGlow   = Color(hex: 0x74A7A1)

    static let cardRadius: CGFloat = 24
}

/// Twinkling stars. Each star has its own size, speed and phase, so they never blink in step.
/// Static when the user has Reduce Motion on.
struct StarField: View {
    var count: Int = 110
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, phase: Double, warm: Bool
    }

    // Deterministic positions, so the sky looks the same every launch.
    private let stars: [Star] = {
        var seed: UInt64 = 0x5EED
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 10_000) / 10_000
        }
        return (0..<110).map { _ in
            Star(x: next(), y: next(),
                 size: 0.8 + next() * 1.8,
                 speed: 0.4 + Double(next()) * 1.2,
                 phase: Double(next()) * .pi * 2,
                 warm: next() < 0.18)
        }
    }()

    /// Shooting stars: one every 5 to 9 seconds, each with its own start point and angle.
    /// Everything is derived from the clock, so there are no timers to manage.
    private struct Meteor {
        let start: CGPoint      // 0...1 of the view
        let angle: Double       // radians, mostly downwards to the right or left
        let length: CGFloat     // 0...1 of the view width
        let begin: TimeInterval
        let duration: TimeInterval
    }

    private func meteor(at t: TimeInterval) -> Meteor? {
        let slot: TimeInterval = 7                 // average gap between meteors
        let index = Int(t / slot)
        // cheap hash of the slot index -> four numbers in 0...1
        func h(_ k: Int) -> Double {
            var x = UInt64(index &* 2654435761 &+ k &* 97)
            x ^= x >> 13; x = x &* 0x5bd1e995; x ^= x >> 15
            return Double(x % 10_000) / 10_000
        }
        let duration = 0.6 + h(1) * 0.4
        let begin = TimeInterval(index) * slot + h(2) * (slot - duration - 1)
        guard t >= begin, t <= begin + duration else { return nil }
        let goesRight = h(3) < 0.5
        return Meteor(start: CGPoint(x: goesRight ? 0.05 + h(4) * 0.5 : 0.45 + h(4) * 0.5,
                                     y: 0.05 + h(5) * 0.35),
                      angle: goesRight ? (0.45 + h(6) * 0.35) : (.pi - 0.45 - h(6) * 0.35),
                      length: 0.22 + CGFloat(h(7)) * 0.18,
                      begin: begin, duration: duration)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if !reduceMotion, let m = meteor(at: t) {
                    let progress = (t - m.begin) / m.duration           // 0...1 along its path
                    let fade = progress < 0.15 ? progress / 0.15 : (1 - progress) / 0.85
                    let travel = m.length * size.width * 1.4
                    let dir = CGVector(dx: cos(m.angle), dy: sin(m.angle))
                    let head = CGPoint(x: m.start.x * size.width + dir.dx * travel * progress,
                                       y: m.start.y * size.height + dir.dy * travel * progress)
                    let tailLen = m.length * size.width * 0.6
                    let tail = CGPoint(x: head.x - dir.dx * tailLen, y: head.y - dir.dy * tailLen)
                    var path = Path()
                    path.move(to: tail); path.addLine(to: head)
                    ctx.stroke(path,
                               with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.9 * fade)]),
                                                     startPoint: tail, endPoint: head),
                               style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)),
                             with: .color(.white.opacity(fade)))
                }

                for star in stars.prefix(count) {
                    let twinkle = reduceMotion ? 0.7 : 0.35 + 0.65 * pow(sin(t * star.speed + star.phase), 2)
                    let r = star.size
                    let p = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    let color: Color = star.warm ? Theme.yellow : .white
                    if r > 2.2 {
                        // a soft halo around the bigger stars
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)),
                                 with: .color(color.opacity(0.10 * twinkle)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(twinkle)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Color {
    /// Color from a hex number, e.g. Color(hex: 0x5A7EB1).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Color {
    /// A colour that automatically switches between light and dark appearance, on every Apple platform.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}

/// The big blue pill button used everywhere (HIG: at least 44pt tall, clear label, obvious primary action).
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(tint, in: Capsule())
            .shadow(color: tint.opacity(configuration.isPressed ? 0.1 : 0.4), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Soft background with a couple of blurry blobs, like the mockups.
struct SoftBackground: View {
    var tint: Color = Theme.sky

    var body: some View {
        ZStack {
            Theme.cream
            Circle().fill(tint).frame(width: 380).blur(radius: 90).offset(x: -150, y: -280)
            Circle().fill(tint.opacity(0.75)).frame(width: 320).blur(radius: 90).offset(x: 170, y: 340)
        }
        .ignoresSafeArea()
    }
}

/// A "photo" slot. Uses a real image from the asset catalogue if one exists with that name,
/// otherwise a big emoji on a soft gradient. Add real photos later without touching the code.
struct Illustration: Hashable, Sendable {
    let emoji: String
    var imageName: String? = nil
    var tintIndex: Int = 0
}

/// A country flag. Uses a custom image from Assets when ContentLibrary.flagImages lists one
/// for that country, otherwise the emoji flag.
struct FlagView: View {
    let emoji: String
    var countryID: String? = nil
    var size: CGFloat = 20

    var body: some View {
        if let id = countryID, let name = ContentLibrary.flagImages[id], IllustrationView.imageExists(name) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.35, height: size * 0.95)
                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                .accessibilityLabel("Flag")
        } else {
            Text(emoji).font(.system(size: size))
        }
    }
}

struct IllustrationView: View {
    let art: Illustration
    var emojiSize: CGFloat = 88
    /// true = show the whole photo with some padding (good for cut-out objects),
    /// false = fill the frame edge to edge (good for landscapes).
    var fit: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.tints[art.tintIndex % Theme.tints.count],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let name = art.imageName, Self.imageExists(name) {
                // Color.clear sets the size; the overlaid image never pushes the layout wider.
                Color.clear.overlay {
                    if fit {
                        Image(name).resizable().scaledToFit().padding(20)
                    } else {
                        Image(name).resizable().scaledToFill()
                    }
                }
            } else {
                Text(art.emoji)
                    .font(.system(size: emojiSize))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    static func imageExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #else
        NSImage(named: name) != nil
        #endif
    }
}
