import SwiftUI

/// The ticket that appears after the plane lands on a country.
struct BoardingPassView: View {
    let flight: Flight
    /// Titles of the buttons. nil for both = this country has no game content yet.
    var primaryTitle: String? = nil         // e.g. "Play quiz"
    var secondaryTitle: String? = nil       // e.g. "Monuments"
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var airportCodeFontSize: CGFloat = 34
    @State private var appeared = false
    @State private var perforationY: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false

    private let paper = Color(hex: 0xFCF9F4)
    private let ink = Color(hex: 0x2B3A52)
    private let accent = Theme.terracotta
    private let actionAccent = Color(hex: 0xA3422D)

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = geometry.size.height * 0.65

            ZStack(alignment: .bottom) {
                Color.clear.ignoresSafeArea()
                Rectangle()
                    .fill(paper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)

                ticket(compact: geometry.size.height < 700)
                    .frame(maxWidth: .infinity)
                    .frame(height: panelHeight)
                    .offset(y: (appeared || reduceMotion ? 0 : panelHeight) + dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                guard !isDismissing, value.translation.height > 0 else { return }
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                guard !isDismissing else { return }
                                let threshold = max(100, geometry.size.height * 0.15)
                                if value.translation.height > threshold || value.predictedEndTranslation.height > threshold * 1.5 {
                                    isDismissing = true
                                    withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
                                        dragOffset = panelHeight
                                    }
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 180))
                                        onClose()
                                    }
                                } else {
                                    withAnimation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                    .allowsHitTesting(!isDismissing)
                    .onAppear {
                        guard !reduceMotion else {
                            appeared = true
                            return
                        }
                        withAnimation(.spring(duration: 0.5, bounce: 0.18)) { appeared = true }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
    }

    private func ticket(compact: Bool) -> some View {
        VStack(spacing: 0) {
            Button(action: onClose) {
                Capsule()
                    .fill(ink.opacity(0.28))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close boarding pass")
            .accessibilityHint("Swipe down to return to the destination menu")

            // Main part
            VStack(alignment: .leading, spacing: compact ? 12 : 22) {
                HStack {
                    Label("CASPIAN AIR", systemImage: "airplane.departure")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                    Spacer()
                    Text("BOARDING PASS")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center) {
                    airport(code: flight.from?.id ?? "HOME",
                            name: flight.from?.name ?? "Your home",
                            flag: flight.from?.flag ?? "🏠",
                            countryID: flight.from?.id,
                            alignment: .leading)
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .font(.title3)
                            .foregroundStyle(accent)
                        Rectangle().fill(.secondary.opacity(0.4)).frame(width: 60, height: 1)
                    }
                    Spacer()
                    airport(code: flight.to.id,
                            name: flight.to.name,
                            flag: flight.to.flag,
                            countryID: flight.to.id,
                            alignment: .trailing)
                }

                HStack {
                    field("PASSENGER", "Explorer")
                    Spacer()
                    field("DATE", flight.date.formatted(.dateTime.day().month(.abbreviated)))
                    Spacer()
                    field("GATE", gate)
                    Spacer()
                    field("SEAT", "1A")
                }
            }
            .padding(compact ? 18 : 24)

            perforation
                .padding(.horizontal, compact ? 18 : 24)

            // Tear-off stub
            VStack(spacing: compact ? 10 : 16) {
                barcode
                    .frame(height: compact ? 34 : 48)
                if primaryTitle != nil || secondaryTitle != nil {
                    HStack(spacing: 12) {
                        if let primaryTitle {
                            Button {
                                onPrimary()
                                onClose()
                            } label: {
                                Label(primaryTitle, systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(actionAccent)
                        }
                        if let secondaryTitle {
                            Button {
                                onSecondary()
                                onClose()
                            } label: {
                                Label(secondaryTitle, systemImage: "building.columns")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(ink)
                        }
                    }
                } else {
                    Label("\(flight.to.name) is coming soon", systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(compact ? 18 : 24)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: "ticket")
        .onPreferenceChange(PerforationYKey.self) { y in
            Task { @MainActor in perforationY = y }
        }
        .background { TicketShape(notchY: perforationY).fill(paper, style: FillStyle(eoFill: true)) }
        .clipShape(TicketShape(notchY: perforationY), style: FillStyle(eoFill: true))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Boarding pass to \(flight.to.name)")
    }

    private func airport(code: String, name: String, flag: String, countryID: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            FlagView(emoji: flag, countryID: countryID, size: 34)
            Text(code)
                .font(.system(size: airportCodeFontSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: 130, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private var gate: String {
        String(flight.to.continent.uppercased().filter(\.isLetter).prefix(2))
    }

    private var perforation: some View {
        Line()
            .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            .frame(height: 1)
            // Report where the perforation is, so the notches in TicketShape line up with it.
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: PerforationYKey.self,
                                           value: g.frame(in: .named("ticket")).midY)
                }
            }
    }

    /// Fake barcode generated from the country code, so each country gets its own pattern.
    private var barcode: some View {
        let seeds = (flight.to.id + flight.to.name).unicodeScalars.map { Int($0.value) }
        return HStack(spacing: 2) {
            ForEach(0..<48, id: \.self) { i in
                let seed = seeds[i % seeds.count] + i * 7
                Rectangle()
                    .fill(ink)
                    .frame(width: CGFloat(1 + seed % 3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct PerforationYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Rounded rectangle with two half-circle notches, like a real tear-off ticket.
/// Always draw it with `FillStyle(eoFill: true)` so the circles cut holes instead of adding bumps.
struct TicketShape: Shape {
    var notchY: CGFloat      // vertical position of the perforation, in points
    var cornerRadius: CGFloat = 24
    var notchRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius)
        guard notchY > 0 else { return p }
        let y = rect.minY + notchY
        p.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        return p
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
