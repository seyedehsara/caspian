import SwiftUI

struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var confirmReset = false

    private var total: Int { ContentLibrary.playableCountries.count }
    private var discovered: [QuizCountry] {
        progress.discovered.compactMap { ContentLibrary.country($0) }
    }

    var body: some View {
        @Bindable var progress = progress

        NavigationStack {
            ZStack {
                NightSky()
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack(spacing: 16) {
                            Text("👩🏻")
                                .font(.system(size: 54))
                                .frame(width: 88, height: 88)
                                .background(Theme.sky, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Your name", text: $progress.playerName)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.snow)
                                    .textFieldStyle(.plain)
                                Text("Traveler")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.snowMuted)
                            }
                            Spacer()
                            Label("\(progress.points)", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.inkOnPaper)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(Theme.yellow, in: Capsule())
                                .accessibilityLabel("\(progress.points) points")
                        }

                        // Progress card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                Text("🌍").font(.system(size: 40))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Countries discovered")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.inkOnPaper.opacity(0.7))
                                    Text("\(discovered.count) / \(total)")
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.inkOnPaper)
                                }
                            }
                            ProgressView(value: Double(discovered.count), total: Double(total))
                                .tint(Theme.blue)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

                        // The passport, with one page per stamp
                        VStack(alignment: .leading, spacing: 16) {
                            Text("My Passport")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.snow)
                            if discovered.isEmpty {
                                Text("Choose a destination and tap Explore Now. Pass a quiz and the country is stamped in here.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.snowMuted)
                                    .padding(.vertical, 4)
                            }
                            PassportBookView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)   // white title on the night sky
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Reset progress", role: .destructive) { confirmReset = true }
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .confirmationDialog("Reset your progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { progress.reset() }
            } message: {
                Text("Your points and unlocked countries will be cleared. Handy for demos.")
            }
        }
    }
}
