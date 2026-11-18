import SwiftUI

/// Every country in the game. Unlocked ones are in colour and can be revisited.
struct CollectionView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var browsing: QuizCountry?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                SoftBackground(tint: Theme.mint)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(ContentLibrary.answerCountries) { country in
                            let unlocked = progress.isDiscovered(country.id)
                            Button {
                                browsing = country
                            } label: {
                                CollectionTile(country: country, unlocked: unlocked)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(unlocked ? "\(country.name), unlocked" : "\(country.name), locked")
                            .accessibilityHint("Shows the monuments")
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Collection")
            .sheet(item: $browsing) { country in
                CountryGuideView(country: country)
                    .presentationDetents([.large])
            }
        }
    }
}

struct CollectionTile: View {
    let country: QuizCountry
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 0) {
            IllustrationView(art: ContentLibrary.signature(for: country.id) ?? Illustration(emoji: country.flag),
                             emojiSize: 60, fit: true)
                .frame(height: 120)
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.45)
                .overlay {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                }
            HStack(spacing: 6) {
                FlagView(emoji: country.flag, countryID: country.id, size: 16)
                Text(country.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(unlocked ? 0.08 : 0.03), radius: 12, y: 6)
    }
}
