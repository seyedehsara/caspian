import SwiftUI

/// The ticket that appears after the plane lands on a country.
struct BoardingPassView: View {
    let flight: Flight
    /// Title of the main button. nil = this country has no game content yet.
    var actionTitle: String? = nil
    var onAction: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var perforationY: CGFloat = 0

    private let paper = Color(red: 0.99, green: 0.97, blue: 0.93)
    private let ink = Color(red: 0.12, green: 0.13, blue: 0.18)
    private let accent = Color(red: 0.98, green: 0.45, blue: 0.36)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.16),
                                    Color(red: 0.10, green: 0.12, blue: 0.26)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ticket
                .frame(maxWidth: 420)
                .padding(24)
                .offset(y: appeared ? 0 : 400)
                .rotationEffect(.degrees(appeared ? 0 : -4))
                .onAppear {
                    withAnimation(.spring(duration: 0.7, bounce: 0.25)) { appeared = true }
                }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            // Main part
            VStack(alignment: .leading, spacing: 22) {
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
            .padding(24)

            perforation

            // Tear-off stub
            VStack(spacing: 16) {
                barcode
                    .frame(height: 48)
                if let actionTitle {
                    Button {
                        onAction()
                        dismiss()
                    } label: {
                        Text(actionTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                } else {
                    Label("\(flight.to.name) is coming soon", systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(24)
        }
        .foregroundStyle(ink)
        .coordinateSpace(name: "ticket")
        .onPreferenceChange(PerforationYKey.self) { y in
            Task { @MainActor in perforationY = y }
        }
        .background { TicketShape(notchY: perforationY).fill(paper, style: FillStyle(eoFill: true)) }
        .clipShape(TicketShape(notchY: perforationY), style: FillStyle(eoFill: true))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boarding pass to \(flight.to.name)")
    }

    private func airport(code: String, name: String, flag: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(flag).font(.system(size: 34))
            Text(code)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
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
            .padding(.horizontal, 24)
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
