import SwiftUI

struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var confirmReset = false

    private var total: Int { ContentLibrary.answerCountries.count }
    private var discovered: [QuizCountry] {
        progress.discovered.compactMap { ContentLibrary.country($0) }
    }

    var body: some View {
        @Bindable var progress = progress

        NavigationStack {
            ZStack {
                SoftBackground(tint: Theme.blush)
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
                                    .foregroundStyle(Theme.ink)
                                    .textFieldStyle(.plain)
                                Text("Traveler")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                            }
                            Spacer()
                            Label("\(progress.points)", systemImage: "star.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(Theme.gold.opacity(0.25), in: Capsule())
                                .accessibilityLabel("\(progress.points) points")
                        }

                        // Progress card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                Text("🌍").font(.system(size: 40))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Countries discovered")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.ink.opacity(0.7))
                                    Text("\(discovered.count) / \(total)")
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            ProgressView(value: Double(discovered.count), total: Double(total))
                                .tint(Theme.primary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)

                        // Collection preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Collection")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            if discovered.isEmpty {
                                Text("Press Play on the globe and guess where each photo comes from to start your collection.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                                    .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(discovered) { country in
                                            VStack(spacing: 6) {
                                                IllustrationView(art: ContentLibrary.signature(for: country.id) ?? Illustration(emoji: country.flag),
                                                                 emojiSize: 44, fit: true)
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                                Text(country.name)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Theme.ink)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profile")
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
