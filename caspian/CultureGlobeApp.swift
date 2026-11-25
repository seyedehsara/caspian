import SwiftUI

@main
struct CultureGlobeApp: App {
    @State private var store = CountryStore()
    @State private var progress = ProgressStore()

    init() {
        RoundedAppearance.install()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if progress.hasOnboarded {
                    ContentView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .environment(store)
            .environment(progress)
            // SF Pro Rounded everywhere, with Dynamic Type still working.
            .fontDesign(.rounded)
        }
    }
}

/// SwiftUI's `.fontDesign(.rounded)` covers every SwiftUI text, but the navigation bar titles and
/// the tab bar labels are drawn by UIKit and keep plain SF Pro. This gives them SF Pro Rounded,
/// and makes the large titles off-white so they read on the night sky.
enum RoundedAppearance {
    static func install() {
        #if canImport(UIKit)
        func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let descriptor = base.fontDescriptor
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]])
                .withDesign(.rounded) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: 0))
        }

        let snow = UIColor(red: 0.984, green: 0.973, blue: 0.961, alpha: 1)   // Theme.snow

        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.largeTitleTextAttributes = [.font: rounded(.largeTitle, weight: .bold), .foregroundColor: snow]
        bar.titleTextAttributes = [.font: rounded(.headline, weight: .semibold)]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = bar
        navBar.scrollEdgeAppearance = bar
        navBar.compactAppearance = bar

        let tabItem = UITabBarItem.appearance()
        tabItem.setTitleTextAttributes([.font: rounded(.caption2, weight: .medium)], for: .normal)
        tabItem.setTitleTextAttributes([.font: rounded(.caption2, weight: .semibold)], for: .selected)
        #endif
    }
}
