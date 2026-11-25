import SwiftUI

/// Shown instead of the summary when a country quiz is passed.
/// A passport rises from the bottom, the cover opens on the first stamp collected, the pages turn
/// one by one past every stamp so far, and the new country's stamp slams onto the fresh page.
/// Playing a country again and passing stamps it again: the pages turn past the other stamps,
/// and this country's seal lands on the fresh page once more.
struct PassportStampView: View {
    let country: QuizCountry
    let correct: Int
    let total: Int
    let points: Int
    let onDone: () -> Void

    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation phases, switched on one after another.
    @State private var risen = false        // passport slides up
    @State private var opened = false       // cover turns
    @State private var pastHalf = false     // cover shows its inside
    @State private var turnedCount = 0      // how many previous pages have turned
    @State private var backCount = 0        // how many of them already show their back
    @State private var stamped = false      // stamp lands
    @State private var finished = false     // title, points and button appear

    /// Countries stamped before this one, oldest first (`discovered` grows in order of unlocking).
    /// Each one has its own page; the passport opens on the first and turns past all of them.
    private var previous: [QuizCountry] {
        progress.discovered.filter { $0 != country.id }.compactMap(ContentLibrary.country)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Stamped!")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.snow)
                .opacity(finished ? 1 : 0)
                .offset(y: finished ? 0 : 12)

            passport
                .offset(y: risen ? 0 : 420)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(country.name) stamped in your passport")

            VStack(spacing: 8) {
                Text("\(correct) of \(total) correct. \(country.name) is in your passport.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.snowMuted)
                    .padding(.horizontal, 24)
                Label("+\(points) points", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.inkOnPaper)
                    .padding(.vertical, 10).padding(.horizontal, 18)
                    .background(Theme.yellow, in: Capsule())
            }
            .opacity(finished ? 1 : 0)
            .offset(y: finished ? 0 : 12)

            Spacer()

            Button("Great!", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(finished ? 1 : 0)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .onAppear(perform: play)
    }

    // MARK: - Sequence

    private func play() {
        guard !reduceMotion else {
            risen = true; opened = true; pastHalf = true
            turnedCount = previous.count; backCount = previous.count; stamped = true
            withAnimation(.easeOut(duration: 0.3)) { finished = true }
            return
        }
        Task { @MainActor in
            withAnimation(.spring(duration: 0.7, bounce: 0.25)) { risen = true }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.9)) { opened = true }
            try? await Task.sleep(for: .milliseconds(450))
            pastHalf = true
            try? await Task.sleep(for: .milliseconds(750))
            // Turn past every stamp collected so far, one page at a time.
            for _ in previous {
                try? await Task.sleep(for: .milliseconds(450))   // let the stamp be seen
                withAnimation(.easeInOut(duration: 0.7)) { turnedCount += 1 }
                try? await Task.sleep(for: .milliseconds(350))
                backCount += 1
                try? await Task.sleep(for: .milliseconds(400))
            }
            withAnimation(.spring(duration: 0.32, bounce: 0.35)) { stamped = true }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.4)) { finished = true }
        }
    }

    // MARK: - Passport

    /// Closed: the cover sits centred. Open: the cover lies to the left, the stamped page to the right.
    /// The previous stamps are a stack of pages on the right, oldest on top; each turns over to the
    /// left in order, landing on top of the one before, until the fresh page is uncovered.
    private var passport: some View {
        ZStack {
            // Fresh right page, where the new stamp lands
            PassportPaper()
                .overlay { stampOnPage }
                .frame(width: Passport.pageWidth, height: Passport.pageHeight)
                .offset(x: Passport.pageWidth / 2)
                .zIndex(0)

            // One page per previous stamp, hinged at the spine
            ForEach(Array(previous.enumerated()), id: \.element.id) { index, stampedCountry in
                let isTurned = turnedCount > index
                PassportLeaf(turned: isTurned, showsBack: backCount > index) {
                    PassportStampedPage(country: stampedCountry)
                }
                // Unturned: oldest page on top of the right-hand stack.
                // Turned: each lands on top of the ones turned before it.
                .zIndex(isTurned ? 10 + Double(index) : Double(previous.count - index))
            }

            // Cover, hinged on its left edge
            PassportLeaf(turned: opened, showsBack: false) {
                if pastHalf {
                    PassportInsideCover(name: progress.playerName).scaleEffect(x: -1)   // un-mirror the back
                } else {
                    PassportCoverFront()
                }
            }
            .zIndex(opened ? 0 : 50)   // on top while closed, underneath the turned pages once open
        }
        .frame(width: Passport.pageWidth * 2, height: Passport.pageHeight)
        .offset(x: opened ? 0 : -Passport.pageWidth / 2)   // keep the booklet centred in both states
        .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
    }

    /// The country's seal, slamming onto the page.
    private var stampOnPage: some View {
        StampImage(country: country)
            .frame(width: Passport.stampSize, height: Passport.stampSize)
            .rotationEffect(.degrees(stamped ? Passport.stampTilt : -40))
            .scaleEffect(stamped ? 1 : 2.6)
            .opacity(stamped ? 1 : 0)
            .overlay {
                if stamped && !reduceMotion { SparkleBurst() }
            }
    }
}
