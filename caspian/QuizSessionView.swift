import SwiftUI

/// One play session. Two modes:
/// world: photo questions, every right answer unlocks that country.
/// country: four questions about one country, score enough and it unlocks.
struct QuizSessionView: View {
    let session: QuizSession
    /// Called with the ids of countries unlocked during this session.
    var onFinish: ([String]) -> Void = { _ in }

    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    private enum Step: Hashable {
        case question(Int)
        case result(Int, chosenID: String)
        case summary
    }

    @State private var step: Step = .question(0)
    @State private var correctCount = 0
    @State private var newlyUnlocked: [String] = []
    @State private var pointsEarned = 0

    private var questions: [Question] { session.questions }

    var body: some View {
        ZStack {
            background

            Group {
                switch step {
                case .question(let i):
                    QuestionView(question: questions[i], mode: session.mode) { chosenID in
                        answer(questionIndex: i, chosenID: chosenID)
                    }
                case .result(let i, let chosenID):
                    AnswerResultView(question: questions[i], chosenID: chosenID,
                                     mode: session.mode,
                                     newlyUnlocked: newlyUnlocked.contains(questions[i].countryID) && chosenID == questions[i].correctID) {
                        let next = i + 1
                        if next < questions.count {
                            advance(to: .question(next))
                        } else {
                            finishCountryModeIfNeeded()
                            advance(to: .summary)
                        }
                    }
                case .summary:
                    SessionSummaryView(mode: session.mode, correct: correctCount, total: questions.count,
                                       unlocked: newlyUnlocked, points: pointsEarned) {
                        onFinish(newlyUnlocked)
                        dismiss()
                    }
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .safeAreaInset(edge: .top) { topBar }
        .sensoryFeedback(.impact(weight: .light), trigger: step)
    }

    private func answer(questionIndex i: Int, chosenID: String) {
        let q = questions[i]
        if chosenID == q.correctID {
            correctCount += 1
            pointsEarned += ContentLibrary.pointsPerCorrect
            progress.addPoints(ContentLibrary.pointsPerCorrect)
            if case .world = session.mode, progress.unlock(q.countryID) {
                newlyUnlocked.append(q.countryID)
                pointsEarned += ContentLibrary.pointsPerUnlock
                progress.addPoints(ContentLibrary.pointsPerUnlock)
            }
        }
        advance(to: .result(i, chosenID: chosenID))
    }

    /// In country mode the unlock happens at the end, if the score is high enough.
    private func finishCountryModeIfNeeded() {
        guard case .country(let country) = session.mode,
              correctCount >= ContentLibrary.countryUnlockThreshold,
              progress.unlock(country.id) else { return }
        newlyUnlocked.append(country.id)
        pointsEarned += ContentLibrary.pointsPerUnlock
        progress.addPoints(ContentLibrary.pointsPerUnlock)
    }

    private func advance(to next: Step) {
        withAnimation(.spring(duration: 0.45)) { step = next }
    }

    /// Close button and progress (HIG: always offer a way out).
    private var topBar: some View {
        HStack {
            Button {
                onFinish(newlyUnlocked)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leave the quiz")

            Spacer()

            if case .country(let country) = session.mode {
                HStack(spacing: 6) {
                    FlagView(emoji: country.flag, countryID: country.id, size: 16)
                    Text(country.name).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.ink)
                Spacer()
            }

            if let index = currentIndex {
                Text("\(index + 1) / \(questions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .accessibilityLabel("Question \(index + 1) of \(questions.count)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var currentIndex: Int? {
        switch step {
        case .question(let i), .result(let i, _): return i
        case .summary: return nil
        }
    }

    @ViewBuilder
    private var background: some View {
        switch step {
        case .result(let i, let chosenID):
            // Correct answers wash the screen teal, wrong ones terracotta, both kept soft.
            SoftBackground(tint: chosenID == questions[i].correctID ? Theme.teal.opacity(0.55) : Theme.terracotta.opacity(0.45))
        default:
            SoftBackground(tint: Theme.lavender)
        }
    }
}

// MARK: - Question

struct QuestionView: View {
    let question: Question
    let mode: QuizSession.Mode
    let onAnswer: (String) -> Void

    @State private var pickedID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(question.prompt)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)

                if let art = question.art {
                    IllustrationView(art: art, emojiSize: 110)
                        .aspectRatio(question.options.count > 2 ? 4 / 3 : 1, contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        Button {
                            guard pickedID == nil else { return }
                            pickedID = option.id
                            // A short pause so the player sees their choice highlight.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                onAnswer(option.id)
                            }
                        } label: {
                            OptionLabel(option: option, isPicked: pickedID == option.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 440)
                .padding(.bottom, 24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct OptionLabel: View {
    let option: Question.Option
    let isPicked: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let flag = option.flag { FlagView(emoji: flag, countryID: option.countryID, size: 20) }
            Text(option.title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.primary, lineWidth: isPicked ? 3 : 0))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        .scaleEffect(isPicked ? 1.03 : 1)
        .animation(.spring(duration: 0.3), value: isPicked)
        .contentShape(Capsule())
    }
}

// MARK: - Result

struct AnswerResultView: View {
    let question: Question
    let chosenID: String
    let mode: QuizSession.Mode
    let newlyUnlocked: Bool
    let onNext: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isCorrect: Bool { chosenID == question.correctID }
    private var correctOption: Question.Option? { question.options.first { $0.id == question.correctID } }
    private var country: QuizCountry? { ContentLibrary.country(question.countryID) }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            ZStack {
                if isCorrect && !reduceMotion { SparkleBurst() }
                Image(systemName: isCorrect ? "checkmark" : "xmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 110, height: 110)
                    .background(isCorrect ? Theme.success : Theme.danger, in: Circle())
                    .scaleEffect(shown ? 1 : 0.4)
            }

            VStack(spacing: 10) {
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                if let correctOption {
                    HStack(spacing: 8) {
                        if let flag = correctOption.flag { FlagView(emoji: flag, countryID: correctOption.countryID, size: 22) }
                        Text(isCorrect ? correctOption.title : "It's \(correctOption.title)")
                    }
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .padding(.horizontal, 24)
                }
                if newlyUnlocked, let country {
                    Label("\(country.name) unlocked on your globe", systemImage: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(Theme.gold.opacity(0.3), in: Capsule())
                }
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Did you know?", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(question.fact)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let art = question.art {
                    IllustrationView(art: art, emojiSize: 40)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            Button(action: onNext) {
                Label("Next", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(tint: isCorrect ? Theme.primary : Theme.ink))
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.4)) { shown = true } }
    }
}

// MARK: - Summary

struct SessionSummaryView: View {
    let mode: QuizSession.Mode
    let correct: Int
    let total: Int
    let unlocked: [String]
    let points: Int
    let onDone: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch mode {
        case .world:
            return unlocked.isEmpty ? "Trip complete!" : "You've unlocked\nnew regions!"
        case .country(let c):
            return unlocked.isEmpty ? "Almost there!" : "You've unlocked\n\(c.name)!"
        }
    }

    private var subtitle: String {
        if case .country = mode, unlocked.isEmpty {
            return "\(correct) of \(total) correct. Get \(ContentLibrary.countryUnlockThreshold) right to unlock it."
        }
        return "\(correct) of \(total) correct"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)

            ZStack {
                if !unlocked.isEmpty && !reduceMotion { SparkleBurst() }
                Circle().fill(Theme.sky).frame(width: 200, height: 200)
                if case .country(let c) = mode {
                    FlagView(emoji: c.flag, countryID: c.id, size: 90)
                        .saturation(unlocked.isEmpty ? 0.3 : 1)
                } else if unlocked.isEmpty {
                    Text("🌍").font(.system(size: 90))
                } else {
                    let flagSize: CGFloat = unlocked.count > 3 ? 40 : 60
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: flagSize * 1.4))], spacing: 8) {
                        ForEach(unlocked.compactMap { ContentLibrary.country($0) }) { c in
                            FlagView(emoji: c.flag, countryID: c.id, size: flagSize)
                        }
                    }
                    .frame(width: 180)
                }
            }
            .scaleEffect(shown ? 1 : 0.5)

            VStack(spacing: 8) {
                Text(subtitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .padding(.horizontal, 24)
                Label("+\(points) points", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10).padding(.horizontal, 18)
                    .background(Theme.gold.opacity(0.25), in: Capsule())
            }

            Spacer()

            Button(unlocked.isEmpty && isCountryMode ? "Back to the globe" : "Great!", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.35)) { shown = true } }
    }

    private var isCountryMode: Bool {
        if case .country = mode { return true }
        return false
    }
}

/// Little confetti dots that fly outwards once.
struct SparkleBurst: View {
    @State private var go = false
    private let colors: [Color] = [Theme.gold, Theme.primary, Theme.success, Theme.danger]

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: 10, height: 10)
                    .offset(x: go ? cos(angle) * 110 : 0, y: go ? sin(angle) * 110 : 0)
                    .opacity(go ? 0 : 1)
                    .scaleEffect(go ? 0.4 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { go = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - Country guide (brief + monuments)

/// What opens when the player picks "Monuments" on the ticket or taps a tile in the collection.
struct CountryGuideView: View {
    let country: QuizCountry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SoftBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        if let brief = ContentLibrary.briefs[country.id] {
                            Text(brief)
                                .font(.body)
                                .foregroundStyle(Theme.ink.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(18)
                                .frame(maxWidth: 520, alignment: .leading)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                                .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                                .padding(.horizontal, 20)
                        }
                        LandmarkGalleryView(country: country, landmarks: ContentLibrary.landmarks[country.id] ?? [])
                    }
                    .padding(.top, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle(country.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LandmarkGalleryView: View {
    let country: QuizCountry
    let landmarks: [Landmark]

    @State private var index = 0

    var body: some View {
        if landmarks.isEmpty {
            ContentUnavailableView("Monuments coming soon", systemImage: "building.columns")
        } else {
            let landmark = landmarks[index]

            VStack(spacing: 16) {
                IllustrationView(art: landmark.art, emojiSize: 110)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .frame(maxWidth: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                    .padding(.horizontal, 20)
                    .id(landmark.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                VStack(alignment: .leading, spacing: 6) {
                    Text(landmark.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(landmark.description)
                        .font(.body)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.horizontal, 20)
                .id("text-\(landmark.id)")
                .transition(.opacity)

                HStack {
                    pagerButton("chevron.left", enabled: index > 0) { index -= 1 }
                    Spacer()
                    Text("\(index + 1) / \(landmarks.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                    Spacer()
                    pagerButton("chevron.right", enabled: index < landmarks.count - 1) { index += 1 }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .animation(.spring(duration: 0.4), value: index)
        }
    }

    private func pagerButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 52, height: 52)
                .background(Theme.card, in: Circle())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.primary : Theme.ink.opacity(0.25))
        .disabled(!enabled)
    }
}
