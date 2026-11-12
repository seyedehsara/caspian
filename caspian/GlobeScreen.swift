import SwiftUI

/// Home tab: the globe, the plane, the boarding pass, and the way into a quiz session.
struct GlobeScreen: View {
    @Environment(CountryStore.self) private var store
    @Environment(ProgressStore.self) private var progress

    @State private var selected: Country?
    @State private var flight: Flight?          // the trip currently drawn on screen
    @State private var flightProgress: CGFloat = 0
    @State private var isFlying = false
    @State private var ticket: Flight?          // non-nil = boarding pass is showing
    @State private var lastDestination: Country?

    @State private var session: QuizSession?    // non-nil = quiz is open
    @State private var pendingSession: QuizSession?
    @State private var visiting: QuizCountry?   // landmark gallery for an unlocked country
    @State private var pendingVisit: QuizCountry?

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
        .safeAreaInset(edge: .bottom) { bottomBar }
        .animation(.spring(duration: 0.4), value: selected)
        .animation(.spring(duration: 0.4), value: isFlying)
        .onChange(of: selected) { _, country in
            guard let country else { return }
            startFlight(to: country)
        }
        .sheet(item: $ticket, onDismiss: ticketDismissed) { trip in
            BoardingPassView(flight: trip, actionTitle: ticketAction(for: trip.to)) {
                ticketActionTapped(for: trip.to)
            }
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
        }
        .journeyCover(item: $session) { session in
            QuizSessionView(session: session, onFinish: sessionFinished)
        }
        .sheet(item: $visiting) { country in
            NavigationStack {
                ZStack {
                    SoftBackground()
                    LandmarkGalleryView(country: country, landmarks: ContentLibrary.landmarks[country.id] ?? [])
                }
                .navigationTitle(country.name)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { visiting = nil }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .task { await store.load() }
    }

    // MARK: Game hooks

    /// What the big button on the ticket says, depending on the country's state.
    private func ticketAction(for country: Country) -> String? {
        guard ContentLibrary.answerCountries.contains(where: { $0.id == country.id }) else { return nil }
        return progress.isDiscovered(country.id) ? "Visit \(country.name)" : "Play to unlock \(country.name)"
    }

    private func ticketActionTapped(for country: Country) {
        if progress.isDiscovered(country.id) {
            pendingVisit = ContentLibrary.country(country.id)
        } else {
            pendingSession = ContentLibrary.makeSession(focus: country.id)
        }
    }

    /// When the ticket closes, open whatever the player asked for.
    private func ticketDismissed() {
        withAnimation { flight = nil }
        if let next = pendingSession {
            pendingSession = nil
            session = next
        } else if let next = pendingVisit {
            pendingVisit = nil
            visiting = next
        }
    }

    /// After a session, fly to the last country that got unlocked so the player sees it turn gold.
    private func sessionFinished(unlocked: [String]) {
        guard let id = unlocked.last, let country = store.countries.first(where: { $0.id == id }) else { return }
        if country == selected { selected = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            selected = country
        }
    }

    // MARK: Flight

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

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if isFlying {
            Text("Flying to \(selected?.name ?? "")…")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 12)
                .transition(.opacity)
        } else if let country = selected {
            CountryCard(country: country,
                        unlocked: progress.isDiscovered(country.id),
                        onClose: { selected = nil },
                        onTap: { ticket = flight ?? Flight(from: nil, to: country) })
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            PlayCard { session = ContentLibrary.makeSession() }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

/// "Start your journey" card shown when no country is selected.
struct PlayCard: View {
    @Environment(ProgressStore.self) private var progress
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start your journey")
                        .font(.headline)
                    Text("\(progress.discovered.count) of \(ContentLibrary.answerCountries.count) countries unlocked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("🌍").font(.system(size: 36))
            }
            Button(action: onPlay) {
                Label("Play Now", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        // If your deployment target is below iOS 26 / macOS 26, replace the line above with:
        // .background(.ultraThinMaterial, in: .rect(cornerRadius: 28))
    }
}

/// Small card shown under the globe once a country is selected. Tap it to see the ticket again.
struct CountryCard: View {
    let country: Country
    var unlocked = false
    let onClose: () -> Void
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            Text(country.flag)
                .font(.system(size: 44))

            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.title3.weight(.semibold))
                Text(unlocked ? "Unlocked" : "\(country.continent) · \(country.population.formatted(.number.notation(.compactName))) people")
                    .font(.subheadline)
                    .foregroundStyle(unlocked ? Theme.gold : .secondary)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(16)
        .frame(maxWidth: 520)
        .contentShape(.rect(cornerRadius: 28))
        .onTapGesture(perform: onTap)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        // If your deployment target is below iOS 26 / macOS 26, replace the line above with:
        // .background(.ultraThinMaterial, in: .rect(cornerRadius: 28))
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
