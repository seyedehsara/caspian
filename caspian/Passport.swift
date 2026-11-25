import SwiftUI

/// The pieces of the passport, shared by the stamping animation (after a quiz) and the
/// passport the player browses in their profile.
///
/// Stamps: one image per country in Assets.xcassets named `stamp_<ID>`
/// (stamp_EGY, stamp_ITA, stamp_IRN, stamp_RUS, stamp_MEX), the seal on a transparent background.
/// A country without an image gets a drawn seal with its flag, so nothing breaks.
enum Passport {
    static let pageWidth: CGFloat = 168
    static let pageHeight: CGFloat = 236
    static let stampSize: CGFloat = 128
    static let stampTilt: Double = -12
}

/// Navy cover with the gold globe.
struct PassportCoverFront: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2C4A6B), Color(hex: 0x1E3550)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.yellow.opacity(0.8), lineWidth: 1.5)
                .padding(10)
            VStack(spacing: 18) {
                Text("PASSPORT")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(4)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 54, weight: .regular))
                Text("STAMP")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(3)
            }
            .foregroundStyle(Theme.yellow)
        }
    }
}

/// Cream paper with a faint diagonal pattern.
struct PassportPaper: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xF2EADA))
            Canvas { context, size in
                for i in stride(from: 0, through: Int(size.width + size.height), by: 14) {
                    var p = Path()
                    p.move(to: CGPoint(x: CGFloat(i), y: 0))
                    p.addLine(to: CGPoint(x: 0, y: CGFloat(i)))
                    context.stroke(p, with: .color(Theme.teal.opacity(0.10)), lineWidth: 0.6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.inkOnPaper.opacity(0.12), lineWidth: 1)
        }
    }
}

/// The inside of the cover: the traveller's name.
struct PassportInsideCover: View {
    let name: String

    var body: some View {
        PassportPaper().overlay {
            VStack(spacing: 10) {
                Text(name.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.inkOnPaper)
                Text("EXPLORER")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.inkOnPaper.opacity(0.55))
            }
            .padding(14)
        }
    }
}

/// A page with one country's seal on it.
struct PassportStampedPage: View {
    let country: QuizCountry

    var body: some View {
        PassportPaper().overlay {
            StampImage(country: country)
                .frame(width: Passport.stampSize, height: Passport.stampSize)
                .rotationEffect(.degrees(Passport.stampTilt))
        }
    }
}

/// The seal image for a country, or a drawn seal with its flag when there is no image yet.
struct StampImage: View {
    let country: QuizCountry

    var body: some View {
        if IllustrationView.imageExists("stamp_\(country.id)") {
            Image("stamp_\(country.id)")
                .resizable()
                .scaledToFit()
                .blendMode(.multiply)   // ink on paper
        } else {
            ZStack {
                Circle().stroke(Theme.terracotta, lineWidth: 3)
                Circle().stroke(Theme.terracotta, lineWidth: 1).padding(6)
                VStack(spacing: 2) {
                    Text(country.name.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(country.flag).font(.system(size: 28))
                }
                .padding(12)
            }
            .foregroundStyle(Theme.terracotta)
            .opacity(0.85)
        }
    }
}

/// One leaf of the booklet, hinged on the spine: shows `front` until it is past halfway,
/// then its blank back. Draw it at the right page's position; it turns over to the left.
struct PassportLeaf<Front: View>: View {
    let turned: Bool
    let showsBack: Bool
    @ViewBuilder let front: () -> Front

    var body: some View {
        ZStack {
            if showsBack {
                PassportPaper().scaleEffect(x: -1)   // the back of the page, blank
            } else {
                front()
            }
        }
        .frame(width: Passport.pageWidth, height: Passport.pageHeight)
        .rotation3DEffect(.degrees(turned ? -180 : 0),
                          axis: (x: 0, y: 1, z: 0),
                          anchor: .leading,
                          perspective: 0.5)
        .offset(x: Passport.pageWidth / 2)
    }
}
