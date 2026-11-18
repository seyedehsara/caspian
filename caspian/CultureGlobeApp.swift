import SwiftUI

@main
struct CultureGlobeApp: App {
    @State private var store = CountryStore()
    @State private var progress = ProgressStore()

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
            .animation(.easeInOut(duration: 0.4), value: progress.hasOnboarded)
            .environment(store)
            .environment(progress)
            // SF Pro Rounded everywhere, with Dynamic Type still working.
            .fontDesign(.rounded)
        }
    }
}
