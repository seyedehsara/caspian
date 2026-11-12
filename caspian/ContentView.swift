import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "globe.europe.africa.fill") {
                GlobeScreen()
            }
            Tab("Collection", systemImage: "star.fill") {
                CollectionView()
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
        }
        // Tabs at the bottom on iPhone, a sidebar on iPad and Mac.
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
        .environment(CountryStore())
        .environment(ProgressStore())
}
