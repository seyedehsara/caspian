import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// All the colours and styles in one place, so the whole app stays consistent.
/// Every colour has a light and a dark version (HIG: support both appearances).
enum Theme {
    static let primary   = Color(light: Color(red: 0.23, green: 0.42, blue: 0.96), dark: Color(red: 0.45, green: 0.60, blue: 1.0))
    static let ink       = Color(light: Color(red: 0.12, green: 0.14, blue: 0.22), dark: Color(red: 0.94, green: 0.95, blue: 1.0))
    static let cream     = Color(light: Color(red: 0.99, green: 0.98, blue: 0.95), dark: Color(red: 0.07, green: 0.08, blue: 0.14))
    static let card      = Color(light: .white, dark: Color(red: 0.13, green: 0.15, blue: 0.23))
    static let sky       = Color(light: Color(red: 0.86, green: 0.92, blue: 1.0), dark: Color(red: 0.14, green: 0.20, blue: 0.36))
    static let lavender  = Color(light: Color(red: 0.88, green: 0.85, blue: 0.93), dark: Color(red: 0.20, green: 0.17, blue: 0.30))
    static let mint      = Color(light: Color(red: 0.90, green: 0.97, blue: 0.92), dark: Color(red: 0.08, green: 0.22, blue: 0.15))
    static let blush     = Color(light: Color(red: 1.0, green: 0.93, blue: 0.91), dark: Color(red: 0.28, green: 0.12, blue: 0.12))
    static let success   = Color(red: 0.30, green: 0.76, blue: 0.45)
    static let danger    = Color(red: 0.95, green: 0.42, blue: 0.40)
    static let gold      = Color(red: 0.98, green: 0.78, blue: 0.25)

    /// Soft, cheerful gradients used behind illustrations. Picked by index so cards vary.
    static let tints: [[Color]] = [
        [Color(red: 0.80, green: 0.88, blue: 1.0), Color(red: 0.93, green: 0.96, blue: 1.0)],
        [Color(red: 1.0, green: 0.88, blue: 0.80), Color(red: 1.0, green: 0.96, blue: 0.92)],
        [Color(red: 0.84, green: 0.96, blue: 0.88), Color(red: 0.95, green: 0.99, blue: 0.96)],
        [Color(red: 0.95, green: 0.86, blue: 1.0), Color(red: 0.98, green: 0.95, blue: 1.0)],
        [Color(red: 1.0, green: 0.94, blue: 0.78), Color(red: 1.0, green: 0.98, blue: 0.92)],
    ]

    static let cardRadius: CGFloat = 24
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
            .shadow(color: tint.opacity(configuration.isPressed ? 0.1 : 0.35), radius: 14, y: 8)
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
            Circle().fill(tint).frame(width: 360).blur(radius: 80).offset(x: -140, y: -260)
            Circle().fill(tint.opacity(0.8)).frame(width: 300).blur(radius: 80).offset(x: 160, y: 320)
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
                if fit {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                } else {
                    Image(name)
                        .resizable()
                        .scaledToFill()
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

    private static func imageExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #else
        NSImage(named: name) != nil
        #endif
    }
}
