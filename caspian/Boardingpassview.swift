import SwiftUI

/// The ticket that appears after the plane lands on a country.
///
/// A tall pass, like the ones in Wallet: a green header, the route in big rounded letters, your
/// drawing printed on the paper (resized, never cropped), then a perforation and a tear-off stub
/// with the passenger details and the barcode. To board, you pull the stub down: it resists a little,
/// rips off with a click, and the journey (the quiz) begins.
///
/// Artwork: one image per country in Assets.xcassets named `ticket_<ID>`
/// (ticket_ITA, ticket_IRN, ticket_EGY, ticket_RUS, ticket_MEX): just the drawing, on a cream or
/// white background. Any size, any proportions: the pass fits it in whole.
struct BoardingPassView: View {
    let flight: Flight
    /// Titles of the buttons. nil for both = this country has no game content yet.
    var primaryTitle: String? = nil         // e.g. "Play quiz"
    var secondaryTitle: String? = nil       // e.g. "Monuments"
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var codeFontSize: CGFloat = 40
    @State private var appeared = false
    @State private var isDismissing = false
    @State private var stubDrag: CGFloat = 0
    @State private var torn = false

    private let tearDistance: CGFloat = 64
    private let corner: CGFloat = 18

    private var assetName: String { "ticket_\(flight.to.id)" }
    private var hasArtwork: Bool { IllustrationView.imageExists(assetName) }
    private var canBoard: Bool { primaryTitle != nil }

    /// Height ÷ width of the design, read from the image so it is shown whole.
    private var artAspect: CGFloat {
        guard hasArtwork else { return 2.0 / 3.0 }
        #if canImport(UIKit)
        if let s = UIImage(named: assetName)?.size, s.width > 0 { return s.height / s.width }
        #else
        if let s = NSImage(named: assetName)?.size, s.width > 0 { return s.height / s.width }
        #endif
        return 2.0 / 3.0
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 760
            let cardW = min(geometry.size.width - 36, 400)
            // The design keeps its proportions; on short screens it just gets a little smaller.
            let artW = cardW - 28
            let artH = min(artW * artAspect, geometry.size.height * 0.30)
            let progress = min(stubDrag / tearDistance, 1)

            ZStack {
                scrim

                VStack(spacing: compact ? 12 : 18) {
                    // Main part
                    mainPart(width: cardW, artHeight: artH, compact: compact)
                        .clipShape(TicketPiece(top: corner, bottom: 0, notchesAt: .bottom), style: FillStyle(eoFill: true))
                        .shadow(color: .black.opacity(0.45), radius: 26, y: 14)
                        .zIndex(1)

                    // Tear-off stub, directly under the main part (negative spacing closes the gap).
                    stub(width: cardW, compact: compact)
                        .clipShape(TicketPiece(top: 0, bottom: corner, notchesAt: .top), style: FillStyle(eoFill: true))
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                        .rotationEffect(.degrees(torn ? 14 : Double(progress) * 3), anchor: .top)
                        .offset(y: torn ? geometry.size.height * 0.6 : stubDrag)
                        .opacity(torn ? 0 : 1)
                        .gesture(tearGesture)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(canBoard ? "Ticket stub. \(primaryTitle ?? "")" : "Ticket stub")
                        .accessibilityAddTraits(canBoard ? .isButton : [])
                        .accessibilityHint(canBoard ? "Double tap to tear the stub and board" : "")
                        .accessibilityAction { if canBoard { tear() } }
                        .padding(.top, -(compact ? 12 : 18))
                        .zIndex(0)

                    footer
                        .frame(width: cardW)
                        .padding(.top, 4)
                }
                .frame(width: cardW)
                .offset(y: appeared || reduceMotion ? 0 : geometry.size.height * 0.6)
                .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -3))

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .opacity(appeared || reduceMotion ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) { appeared = true }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: appeared)
        .sensoryFeedback(.success, trigger: torn)
    }

    // MARK: - Main part: header, design, route

    private func mainPart(width: CGFloat, artHeight: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 0) {
            // Header band
            HStack {
                Label("STAMP AIR", systemImage: "airplane.departure")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(2)
                Spacer()
                Text("BOARDING PASS")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(2)
            }
            .foregroundStyle(TicketPalette.paper)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(TicketPalette.green)

            // Route
            HStack(alignment: .top) {
                airport(code: fromID, name: fromName, label: "FROM", alignment: .leading)
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TicketPalette.red)
                    DottedLine()
                        .stroke(TicketPalette.green.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
                        .frame(width: 64, height: 1)
                }
                .padding(.top, 22)
                Spacer()
                airport(code: flight.to.id, name: flight.to.name, label: "TO", alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.top, compact ? 14 : 18)

            // Your drawing, printed straight onto the paper, whole and never cropped
            artwork
                .frame(width: width - 28, height: artHeight)
                .padding(.top, compact ? 6 : 10)
                .padding(.bottom, compact ? 14 : 18)
        }
        .frame(width: width)
        .background(TicketPalette.paper)
    }

    @ViewBuilder
    private var artwork: some View {
        if hasArtwork {
            Image(assetName)
                .resizable()
                .scaledToFit()          // resized, never cropped
                .blendMode(.multiply)   // ink on paper: a white or cream background disappears
                .mask {                 // and the edges fade out, so there is never a hard border
                    Rectangle().padding(14).blur(radius: 14)
                }
                .accessibilityLabel("Drawing of \(flight.to.name)")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(TicketPalette.green.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                VStack(spacing: 6) {
                    Text(flight.to.flag).font(.system(size: 48))
                    Text(flight.to.name.uppercased())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(TicketPalette.green)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func airport(code: String, name: String, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(TicketPalette.green.opacity(0.6))
            Text(code)
                .font(.system(size: codeFontSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(TicketPalette.green)
            Text(name.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(TicketPalette.red)
                .lineLimit(1)
        }
        .frame(maxWidth: 150, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stub: details and barcode

    private func stub(width: CGFloat, compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 16) {
            HStack(alignment: .top) {
                field("PASSENGER", "Explorer", accent: true)
                Spacer()
                field("CLASS", "Discovery")
            }
            HStack(alignment: .top) {
                field("FLIGHT", flightNumber)
                Spacer()
                field("GATE", gate)
                Spacer()
                field("SEAT", "1A")
                Spacer()
                field("DATE", flight.date.formatted(.dateTime.day().month(.abbreviated)))
            }
            VStack(spacing: 4) {
                barcode.frame(height: compact ? 36 : 44)
                Text("TICKET NO · \(ticketNumber)")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(TicketPalette.green.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, compact ? 18 : 22)
        .padding(.bottom, compact ? 16 : 20)
        .frame(width: width)
        .background(TicketPalette.paper)
        .overlay(alignment: .top) {
            DottedLine()
                .stroke(TicketPalette.green.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private func field(_ title: String, _ value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(TicketPalette.green.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(accent ? TicketPalette.red : TicketPalette.green)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// Fake barcode generated from the country code, so each country gets its own pattern.
    private var barcode: some View {
        let seeds = (flight.to.id + flight.to.name).unicodeScalars.map { Int($0.value) }
        return HStack(spacing: 2) {
            ForEach(0..<56, id: \.self) { i in
                let seed = seeds[i % seeds.count] + i * 7
                Rectangle()
                    .fill(TicketPalette.green)
                    .frame(width: CGFloat(1 + seed % 3))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - Values

    private var fromID: String {
        if let from = flight.from, from.id != flight.to.id { return from.id }
        return "HOME"
    }
    private var fromName: String {
        if let from = flight.from, from.id != flight.to.id { return from.name }
        return "Your home"
    }
    private var gate: String {
        String(flight.to.continent.uppercased().filter(\.isLetter).prefix(2))
    }
    /// e.g. "ST 922": a stable number per country, so Italy always flies the same flight.
    private var flightNumber: String {
        let n = flight.to.id.unicodeScalars.reduce(0) { $0 * 31 + Int($1.value) } % 900 + 100
        return "ST \(n)"
    }
    private var ticketNumber: String {
        let n = flight.to.name.unicodeScalars.reduce(7) { ($0 * 33 + Int($1.value)) % 1_000_000 }
        return String(format: "%06d", n) + flight.to.id
    }

    // MARK: - Tearing and closing

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard canBoard, !torn, !isDismissing else { return }
                // Resist a little, like real paper.
                let d = max(0, value.translation.height)
                stubDrag = d < tearDistance ? d : tearDistance + (d - tearDistance) * 0.25
            }
            .onEnded { value in
                guard canBoard, !torn, !isDismissing else { return }
                if value.translation.height > tearDistance || value.predictedEndTranslation.height > tearDistance * 1.6 {
                    tear()
                } else {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3)) { stubDrag = 0 }
                }
            }
    }

    private func tear() {
        guard canBoard, !torn else { return }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.4)) { torn = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 420))
            onPrimary()
            onClose()
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 200))
            onClose()
        }
    }

    // MARK: - Around the ticket

    private var scrim: some View {
        ZStack {
            Color.black.opacity(appeared || reduceMotion ? 0.58 : 0)
            RadialGradient(colors: [TicketPalette.paper.opacity(0.14), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
                .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TicketPalette.paper)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close boarding pass")
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            if let primaryTitle {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                    Text("Pull the stub down to \(primaryTitle.lowercased())")
                    Image(systemName: "arrow.down")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(TicketPalette.paper.opacity(0.9))
                .multilineTextAlignment(.center)
            } else {
                Label("\(flight.to.name) is coming soon", systemImage: "clock")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(TicketPalette.paper.opacity(0.75))
            }

            if let secondaryTitle {
                Button {
                    onSecondary()
                    onClose()
                } label: {
                    Label(secondaryTitle, systemImage: "building.columns")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(TicketPalette.paper)
            }
        }
    }
}

// MARK: - Palette and shapes

/// The printed-ticket colours. `paper` is the cream of the drawings, so they print onto the
/// pass with no edge around them.
enum TicketPalette {
    static let paper = Color(hex: 0xF2EADA)
    static let green = Color(hex: 0x2E5A45)
    static let red   = Color(hex: 0xB8432F)
}

/// One half of a tear-off ticket: rounded on one end, straight at the perforation, with the
/// half-circle notches cut out at the perforation corners. Draw with `FillStyle(eoFill: true)`.
struct TicketPiece: Shape {
    enum Edge { case top, bottom }
    var top: CGFloat
    var bottom: CGFloat
    var notchesAt: Edge
    var notchRadius: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerRadii: RectangleCornerRadii(topLeading: top, bottomLeading: bottom,
                                                                     bottomTrailing: bottom, topTrailing: top),
                         style: .continuous)
        let y = notchesAt == .top ? rect.minY : rect.maxY
        p.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        return p
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
