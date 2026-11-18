import SwiftUI

/// Home tab: the globe, the destination chips, the plane, the boarding pass, and the way into a quiz.
///
/// Flow: pick a destination (tap the globe or a chip) or leave it on Shuffle, press the big button,
/// the plane flies there, the boarding pass opens, and its buttons start the game or the monuments.
struct GlobeScreen: View {
    @Environment(CountryStore.self) private var store
    @Environment(ProgressStore.self) private var progress

    @State private var selected: Country?           // nil = Shuffle
    @State private var flight: Flight?              // the trip currently drawn on screen
    @State private var flightProgress: CGFloat = 0
    @State private var isFlying = false
    @State private var ticket: Flight?              // non-nil = boarding pass is showing
    @State private var lastDestination: Country?

    @State private var shuffleSession: QuizSession? // built when Explore Now is pressed in Shuffle mode
    @State private var pendingSession: QuizSession? // launched when the ticket closes
    @State private var pendingVisit: QuizCountry?
    @State private var session: QuizSession?        // non-nil = quiz is open
    @State private var visiting: QuizCountry?       // non-nil = monuments are open

    var body: some View {
        ZStack {
            backdrop

            if store.isLoaded {
                GlobeView(selected: $selected, discovered: progress.discoveredIDs)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let error = store.loadError {
                ContentUnavailableView("Couldn't load the map", systemImage: "globe", description: Text(error))
            } else {
                ProgressView("Loading the world…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            if flight != nil {
                FlightOverlay(progress: flightProgress)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: store.isLoaded)
        .safeAreaInset(edge: .bottom) {
            if store.isLoaded {
                bottomBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: selected)
        .animation(.spring(duration: 0.35), value: isFlying)
        .sheet(item: $ticket, onDismiss: ticketDismissed) { trip in
            if let shuffle = shuffleSession {
                // Shuffle trip: one button that starts the random game.
                BoardingPassView(flight: trip, primaryTitle: "Start your journey") {
                    pendingSession = shuffle
                }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
            } else {
                let playable = ContentLibrary.hasCountryQuiz(trip.to.id)
                BoardingPassView(flight: trip,
                                 primaryTitle: playable ? (progress.isDiscovered(trip.to.id) ? "Play again" : "Play quiz") : nil,
                                 secondaryTitle: playable ? "Monuments" : nil,
                                 onPrimary: { if let c = ContentLibrary.country(trip.to.id) { pendingSession = ContentLibrary.makeCountrySession(for: c) } },
                                 onSecondary: { pendingVisit = ContentLibrary.country(trip.to.id) })
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .journeyCover(item: $session) { session in
            QuizSessionView(session: session, onFinish: sessionFinished)
        }
        .sheet(item: $visiting) { country in
            CountryGuideView(country: country)
                .presentationDetents([.large])
        }
        .task { await store.load() }
    }

    // MARK: Journey

    /// The big button. Shuffle: random game, plane flies to its first country. Country: fly there.
    private func startJourney() {
        guard !isFlying else { return }
        if let country = selected {
            shuffleSession = nil
            startFlight(to: country)
        } else {
            let next = ContentLibrary.makeSession()
            guard let firstID = next.questions.first?.countryID,
                  let destination = store.countries.first(where: { $0.id == firstID }) else { return }
            shuffleSession = next
            selected = destination            // turns the globe and highlights the chip
            startFlight(to: destination)
        }
    }

    private func startFlight(to country: Country) {
        let newFlight = Flight(from: lastDestination, to: country)
        lastDestination = country
        flight = newFlight
        flightProgress = 0
        isFlying = true

        // Let SwiftUI draw the plane at the start first, then animate it to the end.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeInOut(duration: GlobeView.flightDuration)) {
                flightProgress = 1
            } completion: {
                isFlying = false
                ticket = newFlight
            }
        }
    }

    /// When the ticket closes, open whatever the player asked for.
    private func ticketDismissed() {
        withAnimation { flight = nil }
        shuffleSession = nil
        if let next = pendingSession {
            pendingSession = nil
            session = next
        } else if let next = pendingVisit {
            pendingVisit = nil
            visiting = next
        }
    }

    /// After a session, turn the globe to the last country unlocked so the player sees it glow.
    private func sessionFinished(unlocked: [String]) {
        guard let id = unlocked.last, let country = store.countries.first(where: { $0.id == id }) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            selected = country
        }
    }

    // MARK: Bottom bar

    /// Countries with quiz content, in the order they appear in Content.swift.
    private var destinations: [Country] {
        ContentLibrary.answerCountries.compactMap { quiz in store.countries.first { $0.id == quiz.id } }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            DestinationChips(countries: destinations, selected: $selected)

            Button(action: startJourney) {
                Label(buttonTitle, systemImage: "airplane.departure")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isFlying)
            .padding(.horizontal, 16)
            .frame(maxWidth: 480)
            .accessibilityHint(selected == nil ? "Starts a random game" : "Flies to \(selected?.name ?? "") and opens its ticket")
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            // Soft fade so the chips never fight with the globe.
            LinearGradient(colors: [.clear, Theme.nightBottom.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .padding(.top, -40)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var buttonTitle: String {
        if isFlying { return "Flying to \(selected?.name ?? "")…" }
        if let country = selected { return "Fly to \(country.name)" }
        return "Explore Now"
    }

    /// Deep teal night sky with twinkling stars.
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Theme.nightTop, Theme.nightBottom],
                           startPoint: .top, endPoint: .bottom)
            StarField()
        }
        .ignoresSafeArea()
    }
}

/// Horizontal row of destination chips. "Shuffle" first, then every playable country.
/// Tapping a chip selects that country (the globe turns to it); tapping the globe selects its chip.
struct DestinationChips: View {
    let countries: [Country]
    @Binding var selected: Country?
    @Environment(ProgressStore.self) private var progress

    private let shuffleID = "__shuffle__"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(id: shuffleID, isSelected: selected == nil) {
                        Image(systemName: "shuffle")
                            .font(.subheadline.weight(.bold))
                        Text("Shuffle")
                    } action: {
                        selected = nil
                    }

                    ForEach(countries) { country in
                        let unlocked = progress.isDiscovered(country.id)
                        chip(id: country.id, isSelected: selected?.id == country.id, unlocked: unlocked) {
                            FlagView(emoji: country.flag, countryID: country.id, size: 16)
                            Text(country.name)
                        } action: {
                            selected = country
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selected) { _, country in
                withAnimation(.spring(duration: 0.4)) {
                    proxy.scrollTo(country?.id ?? shuffleID, anchor: .center)
                }
            }
        }
        .accessibilityLabel("Destination")
    }

    @ViewBuilder
    private func chip<Content: View>(id: String, isSelected: Bool, unlocked: Bool = false,
                                     @ViewBuilder label: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.yellow)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Theme.ink : .white)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background {
                if isSelected {
                    Capsule().fill(Theme.yellow)
                } else {
                    Capsule().fill(.white.opacity(0.12))
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// Full screen on iPhone and iPad, a large sheet on Mac (which has no full screen cover).
    @ViewBuilder
    func journeyCover<Item: Identifiable, Content: View>(item: Binding<Item?>,
                                                         @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item) { item in
            content(item).frame(minWidth: 520, minHeight: 720)
        }
        #endif
    }
}
