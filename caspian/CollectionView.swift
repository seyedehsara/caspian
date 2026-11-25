import SwiftUI

/// Every country in the game, each with its postage stamps.
/// Pass a country's quiz to unlock it, then spend the points you earn on its stamps.
struct CollectionView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var browsing: QuizCountry?
    @State private var viewing: PostageStamp?

    var body: some View {
        NavigationStack {
            ZStack {
                NightSky()
                ScrollView {
                    VStack(spacing: 22) {
                        balance

                        ForEach(ContentLibrary.playableCountries) { country in
                            CountryStampsSection(country: country,
                                                 unlocked: progress.isDiscovered(country.id),
                                                 onOpenGuide: { browsing = country },
                                                 onView: { viewing = $0 })
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Collection")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .sheet(item: $browsing) { country in
                CountryGuideView(country: country)
                    .presentationDetents([.large])
            }
            .sheet(item: $viewing) { stamp in
                PostageStampDetail(stamp: stamp)
            }
        }
    }

    /// Points to spend, and how stamps are earned.
    private var balance: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your points")
                    .font(.subheadline)
                    .foregroundStyle(Theme.snowMuted)
                Text("Each stamp costs \(ContentLibrary.stampPrice). Earn points by playing.")
                    .font(.caption)
                    .foregroundStyle(Theme.snowMuted.opacity(0.8))
            }
            Spacer()
            Label("\(progress.points)", systemImage: "star.fill")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkOnPaper)
                .padding(.vertical, 8).padding(.horizontal, 16)
                .background(Theme.yellow, in: Capsule())
                .contentTransition(.numericText())
                .animation(.default, value: progress.points)
                .accessibilityLabel("\(progress.points) points")
        }
        .padding(16)
        .background(Theme.snow.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

// MARK: - One country

struct CountryStampsSection: View {
    let country: QuizCountry
    let unlocked: Bool
    let onOpenGuide: () -> Void
    let onView: (PostageStamp) -> Void

    private var stamps: [PostageStamp] { ContentLibrary.postageStamps(for: country.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Country row: name, lock state, and a way into the monuments
            Button(action: onOpenGuide) {
                HStack(spacing: 10) {
                    FlagView(emoji: country.flag, countryID: country.id, size: 24)
                    Text(country.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.snow)
                    Spacer()
                    if unlocked {
                        Label("Unlocked", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.inkOnPaper)
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Theme.yellow, in: Capsule())
                    } else {
                        Label("Locked", systemImage: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.snowMuted)
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Theme.snow.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.snowMuted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(unlocked ? "\(country.name), unlocked" : "\(country.name), locked")
            .accessibilityHint("Shows the monuments")

            if stamps.isEmpty {
                Text("Stamps coming soon")
                    .font(.subheadline)
                    .foregroundStyle(Theme.snowMuted)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(stamps) { stamp in
                            PostageStampCard(stamp: stamp, countryUnlocked: unlocked) { onView(stamp) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }
}

// MARK: - One stamp

struct PostageStampCard: View {
    let stamp: PostageStamp
    let countryUnlocked: Bool
    let onView: () -> Void

    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var justBought = false

    private var owned: Bool { progress.owns(stamp) }
    private var canBuy: Bool { countryUnlocked && !owned && progress.canAfford(stamp) }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: owned ? onView : buy) {
                PostageStampImage(stamp: stamp)
                    .frame(width: 128, height: 170)
                    .saturation(owned ? 1 : 0)
                    .opacity(owned ? 1 : 0.45)
                    .overlay {
                        if !owned {
                            Image(systemName: countryUnlocked ? "star.fill" : "lock.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                    }
                    .scaleEffect(justBought && !reduceMotion ? 1.08 : 1)
                    .shadow(color: .black.opacity(owned ? 0.4 : 0.15), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!owned && !canBuy)

            Text(stamp.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.snow)
                .lineLimit(1)

            if owned {
                Label("Yours", systemImage: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.teal)
            } else if !countryUnlocked {
                Text("Pass the quiz first")
                    .font(.caption2)
                    .foregroundStyle(Theme.snowMuted)
            } else {
                Button(action: buy) {
                    Label("\(stamp.price)", systemImage: "star.fill")
                        .font(.caption.weight(.bold))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.yellow)
                .foregroundStyle(Theme.inkOnPaper)
                .disabled(!canBuy)
                .accessibilityLabel("Get for \(stamp.price) points")
            }
        }
        .frame(width: 128)
        .sensoryFeedback(.success, trigger: justBought)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stamp.title), \(owned ? "yours" : countryUnlocked ? "\(stamp.price) points" : "locked")")
    }

    private func buy() {
        guard progress.buy(stamp) else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.5)) { justBought = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { justBought = false }
        }
    }
}

/// The stamp picture, or a plain placeholder if the image is not in the assets yet.
struct PostageStampImage: View {
    let stamp: PostageStamp

    var body: some View {
        if IllustrationView.imageExists(stamp.id) {
            Image(stamp.id)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.paper)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "envelope")
                            .font(.title)
                        Text(stamp.title)
                            .font(.caption2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.inkOnPaper.opacity(0.6))
                    .padding(8)
                }
        }
    }
}

/// A bought stamp, big, on its own sheet.
struct PostageStampDetail: View {
    let stamp: PostageStamp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NightSky()
            VStack(spacing: 20) {
                Spacer()
                PostageStampImage(stamp: stamp)
                    .frame(maxWidth: 360, maxHeight: 480)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
                    .padding(.horizontal, 24)
                VStack(spacing: 6) {
                    Text(stamp.title)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.snow)
                    if let country = ContentLibrary.country(stamp.countryID) {
                        HStack(spacing: 6) {
                            FlagView(emoji: country.flag, countryID: country.id, size: 18)
                            Text(country.name)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.snowMuted)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }
}
