import SwiftUI

/// Home tab: the globe, destination selector, and quiz session entry point.
struct GlobeScreen: View {
    private static let shuffleID = "__shuffle__"

    @Environment(CountryStore.self) private var store
    @Environment(ProgressStore.self) private var progress

    @State private var selected: Country?
    // Shuffle is the default mode; choosing a country previews it and focuses the next game.
    @State private var destinationID = GlobeScreen.shuffleID
    @State private var destinationChangeTask: Task<Void, Never>?

    @State private var session: QuizSession?    // non-nil = quiz is open
    @State private var pendingSession: QuizSession?
    @State private var boardingPass: Flight?
    @State private var launchSessionAfterBoarding = false
    @State private var suppressBoardingPassForSelection = false
    @State private var flightProgress: CGFloat = 0
    @State private var isFlying = false

    var body: some View {
        ZStack {
            backdrop

            GeometryReader { geometry in
                let controlsHeight = min(max(geometry.size.height * 0.382, 176), geometry.size.height * 0.56)
                let globeHeight = geometry.size.height - controlsHeight

                VStack(spacing: 0) {
                    Group {
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
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: globeHeight)

                    bottomBar
                        .frame(maxWidth: .infinity)
                        .frame(height: controlsHeight, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isFlying {
                FlightOverlay(progress: flightProgress)
                    .transition(.opacity)
            }

        }
        .animation(.easeOut(duration: 0.5), value: store.isLoaded)
        .animation(.spring(duration: 0.4), value: selected)
        .onChange(of: selected) { _, country in
            destinationID = country?.id ?? Self.shuffleID
        }
        .onChange(of: destinationID) { _, id in
            // Wheel pickers can report intermediate rows while the wheel is still spinning.
            // Wait for the wheel to settle, then wait for the globe turn before showing a pass.
            destinationChangeTask?.cancel()
            destinationChangeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, destinationID == id else { return }
                guard id != Self.shuffleID else {
                    if selected != nil { selected = nil }
                    return
                }
                guard let country = store.countries.first(where: { $0.id == id }) else { return }
                if selected?.id != id { selected = country }
                guard !suppressBoardingPassForSelection else {
                    suppressBoardingPassForSelection = false
                    return
                }
                try? await Task.sleep(for: .seconds(GlobeView.turnDuration))
                guard !Task.isCancelled, destinationID == id, selected?.id == id else { return }
                showBoardingPass(for: country)
            }
        }
        .sheet(item: $boardingPass, onDismiss: boardingPassDismissed) { flight in
            let hasGame = ContentLibrary.answerCountries.contains { $0.id == flight.to.id }
            BoardingPassView(flight: flight, actionTitle: hasGame ? "Start Your Journey" : nil) {
                launchSessionAfterBoarding = true
            }
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
        }
        .journeyCover(item: $session) { session in
            QuizSessionView(session: session, onFinish: sessionFinished)
        }
        .task { await store.load() }
    }

    /// After a session, center the globe on the last country unlocked so its highlight is visible.
    private func sessionFinished(unlocked: [String]) {
        guard let id = unlocked.last, let country = store.countries.first(where: { $0.id == id }) else { return }
        suppressBoardingPassForSelection = true
        if country == selected { selected = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            selected = country
        }
    }

    /// Shuffle mode uses the button, a short flight, and then the boarding pass.
    private func startJourney() {
        guard !isFlying else { return }
        let focus = destinationID == Self.shuffleID ? nil : destinationID
        let nextSession = ContentLibrary.makeSession(focus: focus)
        guard let arrivalID = nextSession.questions.first?.answerID,
              let destination = store.countries.first(where: { $0.id == arrivalID }) else { return }

        pendingSession = nextSession
        let flight = Flight(from: nil, to: destination)
        flightProgress = 0
        isFlying = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeInOut(duration: Self.journeyFlightDuration)) {
                flightProgress = 1
            } completion: {
                isFlying = false
                boardingPass = flight
            }
        }
    }

    /// A manually selected country opens its ticket immediately, without the plane animation.
    private func showBoardingPass(for country: Country) {
        let hasGame = ContentLibrary.answerCountries.contains { $0.id == country.id }
        pendingSession = hasGame ? ContentLibrary.makeSession(focus: country.id) : nil
        launchSessionAfterBoarding = false
        boardingPass = Flight(from: nil, to: country)
    }

    /// Keep the game behind the Caspian Air pass until its button is pressed.
    private func boardingPassDismissed() {
        if launchSessionAfterBoarding {
            launchSessionAfterBoarding = false
            session = pendingSession
        }
        pendingSession = nil
    }

    private static let journeyFlightDuration: TimeInterval = 1.6

    /// Countries with at least one quiz question, ordered by the map's country names.
    private var availableCountries: [Country] {
        let availableIDs = Set(ContentLibrary.answerCountries.map(\.id))
        return store.countries.filter { availableIDs.contains($0.id) }
    }

    // MARK: Destination selector

    /// Native SwiftUI wheel picker, styled as a compact glass destination selector.
    private var destinationPicker: some View {
        Picker("Destination", selection: $destinationID) {
            HStack(spacing: 9) {
                Text("🌍")
                Text("Shuffle")
                    .fontWeight(.semibold)
            }
            .tag(Self.shuffleID)

            ForEach(availableCountries) { country in
                HStack(spacing: 9) {
                    Text(country.flag)
                    Text(country.name)
                        .fontWeight(.medium)
                }
                .tag(country.id)
            }
        }
        .pickerStyle(.wheel)
        .tint(Theme.gold)
        .environment(\.colorScheme, .dark)
        .labelsHidden()
        .frame(height: 104)
        .clipped()
        .accessibilityHint("Choose Shuffle for a random game or select a country to highlight it on the globe")
        .frame(maxWidth: 440)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if store.isLoaded {
                destinationPicker
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if store.isLoaded {
                ExploreNowButton(isDisabled: isFlying, action: startJourney)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    /// Deep space gradient with a soft glow behind the globe.
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.12),
                                    Color(red: 0.08, green: 0.10, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.35), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

/// Shuffle-mode game launch button shown below the destination selector.
struct ExploreNowButton: View {
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Explore Now")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isDisabled)
        .frame(maxWidth: 520)
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
