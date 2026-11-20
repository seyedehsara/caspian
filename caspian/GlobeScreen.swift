import SwiftUI

/// Home tab: the globe, native destination wheel, and the Caspian Air boarding pass.
/// Picking a country turns the globe first; Shuffle starts the separate flight animation.
struct GlobeScreen: View {
    private static let shuffleID = "__shuffle__"

    @Environment(CountryStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selected: Country?
    @State private var destinationID = GlobeScreen.shuffleID
    @State private var isBrowsingManually = false
    @State private var isPickerExpanded = false
    @State private var pickerIdleTask: Task<Void, Never>?
    @State private var destinationChangeTask: Task<Void, Never>?
    @State private var suppressAutomaticTicket = false
    @State private var isTurningToSelection = false

    @State private var flight: Flight?
    @State private var flightProgress: CGFloat = 0
    @State private var isFlying = false
    @State private var ticket: Flight?
    @State private var lastDestination: Country?

    @State private var shuffleSession: QuizSession?
    @State private var pendingSession: QuizSession?
    @State private var pendingVisit: QuizCountry?
    @State private var session: QuizSession?
    @State private var visiting: QuizCountry?

    @ScaledMetric(relativeTo: .body) private var compactPickerHeight: CGFloat = 116
    @ScaledMetric(relativeTo: .body) private var expandedPickerHeight: CGFloat = 194

    private var pickerHeight: CGFloat {
        isPickerExpanded ? expandedPickerHeight : compactPickerHeight
    }

    var body: some View {
        ZStack {
            backdrop
            bottomGradient

            GeometryReader { geometry in
                let controlsHeight = min(max(geometry.size.height * 0.382, 176), geometry.size.height * 0.56)
                let globeHeight = geometry.size.height - controlsHeight

                VStack(spacing: 0) {
                    Group {
                        if store.isLoaded {
                            GlobeView(selected: $selected, discovered: progress.discoveredIDs)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                .allowsHitTesting(!isFlying)
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
                .overlay {
                    if flight != nil {
                        FlightOverlay(
                            progress: flightProgress,
                            globeFrame: CGRect(x: 0, y: 0, width: geometry.size.width, height: globeHeight)
                        )
                        .transition(.opacity)
                    }
                }
            }

            if let trip = ticket {
                boardingPassOverlay(for: trip)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: store.isLoaded)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: selected)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: isFlying)
        .onChange(of: selected) { _, country in
            let newID = country?.id ?? Self.shuffleID
            if destinationID != newID { destinationID = newID }
        }
        .onChange(of: destinationID) { _, id in
            destinationChangeTask?.cancel()
            guard id != Self.shuffleID else {
                isTurningToSelection = false
                shuffleSession = nil
                if selected != nil { selected = nil }
                return
            }

            // Wait for the native wheel to settle before starting a country preview.
            isTurningToSelection = true
            destinationChangeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, destinationID == id else { return }
                guard let country = store.countries.first(where: { $0.id == id }) else {
                    isTurningToSelection = false
                    return
                }

                if suppressAutomaticTicket {
                    suppressAutomaticTicket = false
                    isTurningToSelection = false
                    return
                }

                if selected?.id != id { selected = country }
                try? await Task.sleep(for: .seconds(reduceMotion ? 0 : GlobeView.turnDuration))
                guard !Task.isCancelled, destinationID == id,
                      selected?.id == id, !isFlying, ticket == nil else { return }

                isTurningToSelection = false
                shuffleSession = nil
                let trip = Flight(from: lastDestination, to: country)
                lastDestination = country
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { ticket = trip }
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
        .toolbar(ticket == nil ? .visible : .hidden, for: .tabBar)
    }

    @ViewBuilder
    private func boardingPassOverlay(for trip: Flight) -> some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            if let shuffle = shuffleSession {
                BoardingPassView(
                    flight: trip,
                    primaryTitle: "Start your journey",
                    onPrimary: { pendingSession = shuffle },
                    onClose: ticketDismissed
                )
            } else {
                let quizCountry = ContentLibrary.country(trip.to.id)
                let playable = ContentLibrary.playableCountries.contains { $0.id == trip.to.id }
                let hasMonuments = progress.isDiscovered(trip.to.id)
                    && !(ContentLibrary.landmarks[trip.to.id] ?? []).isEmpty
                BoardingPassView(flight: trip,
                                 primaryTitle: playable ? (progress.isDiscovered(trip.to.id) ? "Retake the quiz" : "Take the quiz") : nil,
                                 secondaryTitle: hasMonuments ? "Monuments" : nil,
                                 onPrimary: {
                                     guard let quizCountry else { return }
                                     pendingSession = ContentLibrary.hasCountryQuiz(trip.to.id)
                                         ? ContentLibrary.makeCountrySession(for: quizCountry)
                                         : ContentLibrary.makeSession(focus: trip.to.id)
                                 },
                                 onSecondary: { pendingVisit = quizCountry },
                                 onClose: ticketDismissed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Journey

    /// Explore Now is active in Shuffle mode. The plane animation is independent of country selection.
    private func startJourney() {
        guard destinationID == Self.shuffleID, !isFlying, !isTurningToSelection else { return }
        destinationChangeTask?.cancel()

        let next = ContentLibrary.makeSession()
        guard let firstID = next.questions.first?.countryID,
              let destination = store.countries.first(where: { $0.id == firstID }) else { return }

        shuffleSession = next
        suppressAutomaticTicket = true
        destinationID = destination.id
        selected = destination
        startFlight(to: destination)
    }

    private func startFlight(to country: Country) {
        let newFlight = Flight(from: lastDestination, to: country)
        lastDestination = country
        if reduceMotion {
            ticket = newFlight
            return
        }
        flight = newFlight
        flightProgress = 0
        isFlying = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeInOut(duration: GlobeView.flightDuration)) {
                flightProgress = 1
            } completion: {
                isFlying = false
                withAnimation(.easeOut(duration: 0.2)) { ticket = newFlight }
            }
        }
    }

    /// Close the ticket before opening the requested quiz or country guide.
    private func ticketDismissed() {
        let wasShuffle = shuffleSession != nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            ticket = nil
            flight = nil
        }
        shuffleSession = nil

        if let next = pendingSession {
            pendingSession = nil
            session = next
        } else if let next = pendingVisit {
            pendingVisit = nil
            visiting = next
        }

        if wasShuffle {
            destinationID = Self.shuffleID
            selected = nil
            isBrowsingManually = false
        }
    }

    /// After a session, turn the globe to the last country unlocked so the player sees it glow.
    private func sessionFinished(unlocked: [String]) {
        guard let id = unlocked.last, let country = store.countries.first(where: { $0.id == id }) else { return }
        guard country != selected else { return }
        suppressAutomaticTicket = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            selected = country
        }
    }

    // MARK: Destination selector

    /// Countries with either world or country-specific quiz content, in map order.
    private var destinations: [Country] {
        let ids = Set(ContentLibrary.playableCountries.map(\.id))
        return store.countries.filter { ids.contains($0.id) }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Compact native SwiftUI wheel with no custom border or opaque container.
    private var destinationPicker: some View {
        Picker("Destination", selection: pickerSelection) {
            HStack(spacing: 9) {
                Image(systemName: "shuffle")
                    .font(.title3.weight(.semibold))
                Text("Shuffle").font(.title3.weight(.semibold))
            }
            .tag(Self.shuffleID)

            ForEach(destinations) { country in
                HStack(spacing: 9) {
                    FlagView(emoji: country.flag, countryID: country.id, size: 22)
                    Text(country.name).font(.title3.weight(.medium))
                }
                .tag(country.id)
            }
        }
        .pickerStyle(.wheel)
        .tint(.white.opacity(0.76))
        .environment(\.colorScheme, .dark)
        .labelsHidden()
        .frame(height: pickerHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isPickerExpanded)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.24),
                .init(color: .black, location: 0.76),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .background(.clear)
        .disabled(isFlying)
        .accessibilityLabel("Destination")
        .accessibilityHint("Choose Shuffle for a random game or select a country to turn the globe and open its ticket")
        .frame(maxWidth: 440)
    }

    /// Only direct wheel interaction hides the Shuffle action; code-driven destination updates do not.
    private var pickerSelection: Binding<String> {
        Binding(
            get: { destinationID },
            set: { newID in
                pickerIdleTask?.cancel()
                if newID == Self.shuffleID {
                    // Keep the wheel expanded until scrolling settles. Resizing it
                    // while the native picker is moving can make it snap back.
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        isBrowsingManually = false
                    }
                    pickerIdleTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled, destinationID == Self.shuffleID else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                            isPickerExpanded = false
                        }
                    }
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        isBrowsingManually = true
                        isPickerExpanded = true
                    }
                }
                destinationID = newID
            }
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if store.isLoaded {
                destinationPicker
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.isLoaded {
                ZStack {
                    if isBrowsingManually {
                        Color.clear
                            .accessibilityHidden(true)
                    } else {
                        Button(action: startJourney) {
                            Label("Explore Now", systemImage: "airplane.departure")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(destinationID != Self.shuffleID || isFlying || isTurningToSelection)
                        .accessibilityHint(destinationID == Self.shuffleID
                                           ? "Starts a random game"
                                           : "The selected country will open after the globe finishes turning")
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: 480)
                .frame(height: 54)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isBrowsingManually)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    /// Fade under the controls, anchored to the physical bottom of the screen.
    private var bottomGradient: some View {
        GeometryReader { geometry in
            let height = geometry.size.height * 0.42
            LinearGradient(colors: [.clear, Theme.nightBottom.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: geometry.size.width, height: height)
                .position(x: geometry.size.width / 2, y: geometry.size.height - height / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Theme.nightTop, Theme.nightBottom], startPoint: .top, endPoint: .bottom)
            StarField()
        }
        .ignoresSafeArea()
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
