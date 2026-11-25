import SwiftUI

/// The player's passport in their profile. Tap the cover to open it, swipe or tap to turn the
/// pages and see every stamp collected, one per page, in the order they were earned.
struct PassportBookView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var opened = false
    @State private var pastHalf = false
    @State private var turnedCount = 0
    @State private var backCount = 0
    @State private var busy = false     // one page at a time
    @State private var activeIndex: Int?   // the page in motion stays on top while it turns

    private var stamps: [QuizCountry] { progress.discovered.compactMap(ContentLibrary.country) }
    private var remaining: Int { max(0, ContentLibrary.playableCountries.count - stamps.count) }

    var body: some View {
        VStack(spacing: 18) {
            booklet
                .contentShape(Rectangle())
                .onTapGesture { location in
                    if !opened { open() }
                    else if location.x > Passport.pageWidth { turnForward() }
                    else { turnBack() }
                }
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard opened else { return }
                            if value.translation.width < -24 { turnForward() }
                            else if value.translation.width > 24 { turnBack() }
                        }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)

            pager
        }
        .sensoryFeedback(.impact(weight: .light), trigger: turnedCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: opened)
    }

    // MARK: - Booklet

    private var booklet: some View {
        ZStack {
            // Last page: empty, waiting for the next stamp
            PassportPaper()
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: remaining == 0 ? "checkmark.seal.fill" : "seal")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.inkOnPaper.opacity(0.35))
                        Text(remaining == 0 ? "Every country\nstamped" : "\(remaining) more to\ncollect")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.inkOnPaper.opacity(0.5))
                    }
                }
                .frame(width: Passport.pageWidth, height: Passport.pageHeight)
                .offset(x: Passport.pageWidth / 2)
                .zIndex(0)

            // One page per stamp, oldest on top of the right-hand stack
            ForEach(Array(stamps.enumerated()), id: \.element.id) { index, country in
                let isTurned = turnedCount > index
                PassportLeaf(turned: isTurned, showsBack: backCount > index) {
                    PassportStampedPage(country: country)
                }
                .zIndex(index == activeIndex ? 100 : (isTurned ? 10 + Double(index) : Double(stamps.count - index)))
            }

            // Cover
            PassportLeaf(turned: opened, showsBack: false) {
                if pastHalf {
                    PassportInsideCover(name: progress.playerName).scaleEffect(x: -1)
                } else {
                    PassportCoverFront()
                }
            }
            .zIndex(opened ? 0 : 50)
        }
        .frame(width: Passport.pageWidth * 2, height: Passport.pageHeight)
        .offset(x: opened ? 0 : -Passport.pageWidth / 2)
        .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
    }

    /// Page counter and arrows under the booklet (also the VoiceOver way to turn pages).
    private var pager: some View {
        HStack(spacing: 18) {
            Button {
                turnBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!opened)
            .accessibilityLabel(turnedCount == 0 ? "Close passport" : "Previous page")

            Text(opened ? pageText : "Tap the passport to open it")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.snowMuted)
                .frame(minWidth: 180)

            Button {
                if opened { turnForward() } else { open() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(opened && turnedCount == stamps.count)
            .accessibilityLabel(opened ? "Next page" : "Open passport")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(Theme.snow)
        .animation(.default, value: opened)
    }

    private var pageText: String {
        if stamps.isEmpty { return "No stamps yet" }
        if turnedCount < stamps.count { return "\(stamps[turnedCount].name) · \(turnedCount + 1) of \(stamps.count)" }
        return "Next page"
    }

    private var accessibilityText: String {
        if !opened { return "Closed passport with \(stamps.count) stamps. Double tap to open." }
        if turnedCount < stamps.count { return "Passport open on \(stamps[turnedCount].name)" }
        return "Passport open on an empty page"
    }

    // MARK: - Turning

    private func open() {
        guard !opened, !busy else { return }
        busy = true
        if reduceMotion {
            opened = true; pastHalf = true; busy = false
            return
        }
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.8)) { opened = true }
            try? await Task.sleep(for: .milliseconds(400))
            pastHalf = true
            try? await Task.sleep(for: .milliseconds(400))
            busy = false
        }
    }

    private func turnForward() {
        guard opened, !busy, turnedCount < stamps.count else { return }
        busy = true
        if reduceMotion {
            turnedCount += 1; backCount += 1; busy = false
            return
        }
        Task { @MainActor in
            activeIndex = turnedCount
            withAnimation(.easeInOut(duration: 0.6)) { turnedCount += 1 }
            try? await Task.sleep(for: .milliseconds(300))
            backCount += 1
            try? await Task.sleep(for: .milliseconds(300))
            activeIndex = nil
            busy = false
        }
    }

    /// Turns the last turned page back to the right; with no page turned, closes the passport.
    private func turnBack() {
        guard opened, !busy else { return }
        busy = true
        if turnedCount == 0 {
            // Close the cover
            if reduceMotion {
                opened = false; pastHalf = false; busy = false
                return
            }
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.8)) { opened = false }
                try? await Task.sleep(for: .milliseconds(400))
                pastHalf = false
                try? await Task.sleep(for: .milliseconds(400))
                busy = false
            }
            return
        }
        if reduceMotion {
            turnedCount -= 1; backCount -= 1; busy = false
            return
        }
        Task { @MainActor in
            activeIndex = turnedCount - 1
            withAnimation(.easeInOut(duration: 0.6)) { turnedCount -= 1 }
            try? await Task.sleep(for: .milliseconds(300))
            backCount -= 1
            try? await Task.sleep(for: .milliseconds(300))
            activeIndex = nil
            busy = false
        }
    }
}
