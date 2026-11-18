import SwiftUI

/// One play session: a handful of photo questions, then a summary of what got unlocked.
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

    private var questions: [QuizQuestion] { session.questions }

    var body: some View {
        ZStack {
            background

            Group {
                switch step {
                case .question(let i):
                    PhotoQuestionView(question: questions[i]) { chosenID in
                        answer(questionIndex: i, chosenID: chosenID)
                    }
                case .result(let i, let chosenID):
                    AnswerResultView(question: questions[i], chosenID: chosenID,
                                     newlyUnlocked: newlyUnlocked.contains(questions[i].answerID) && chosenID == questions[i].answerID) {
                        let next = i + 1
                        advance(to: next < questions.count ? .question(next) : .summary)
                    }
                case .summary:
                    SessionSummaryView(correct: correctCount, total: questions.count,
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
        if chosenID == q.answerID {
            correctCount += 1
            pointsEarned += ContentLibrary.pointsPerCorrect
            progress.addPoints(ContentLibrary.pointsPerCorrect)
            if progress.unlock(q.answerID) {
                newlyUnlocked.append(q.answerID)
                pointsEarned += ContentLibrary.pointsPerUnlock
                progress.addPoints(ContentLibrary.pointsPerUnlock)
            }
        }
        advance(to: .result(i, chosenID: chosenID))
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
            (chosenID == questions[i].answerID ? Theme.mint : Theme.blush).ignoresSafeArea()
        default:
            SoftBackground(tint: Theme.lavender)
        }
    }
}

// MARK: - Question

struct PhotoQuestionView: View {
    let question: QuizQuestion
    let onAnswer: (String) -> Void

    @State private var pickedID: String?

    var body: some View {
        VStack(spacing: 28) {
            Text(question.prompt)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)

            IllustrationView(art: question.art, emojiSize: 120)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
                .padding(.horizontal, 32)

            VStack(spacing: 14) {
                ForEach(question.optionIDs, id: \.self) { id in
                    if let country = ContentLibrary.country(id) {
                        Button {
                            guard pickedID == nil else { return }
                            pickedID = id
                            // A short pause so the player sees their choice highlight.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                onAnswer(id)
                            }
                        } label: {
                            CountryOptionLabel(country: country, isPicked: pickedID == id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(country.name)
                    }
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 440)

            Spacer(minLength: 0)
        }
    }
}

struct CountryOptionLabel: View {
    let country: QuizCountry
    let isPicked: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(country.flag)
            Text(country.name)
                .font(.headline)
                .foregroundStyle(Theme.ink)
        }
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
    let question: QuizQuestion
    let chosenID: String
    let newlyUnlocked: Bool
    let onNext: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isCorrect: Bool { chosenID == question.answerID }
    private var answer: QuizCountry? { ContentLibrary.country(question.answerID) }

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
                if let answer {
                    HStack(spacing: 8) {
                        Text(answer.flag)
                        Text(isCorrect ? answer.name : "It's from \(answer.name)")
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                }
                if newlyUnlocked, let answer {
                    Label("\(answer.name) unlocked on your globe", systemImage: "lock.open.fill")
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
                IllustrationView(art: question.art, emojiSize: 40)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
    let correct: Int
    let total: Int
    let unlocked: [String]
    let points: Int
    let onDone: () -> Void

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(unlocked.isEmpty ? "Trip complete!" : "You've unlocked\nnew regions!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)

            ZStack {
                if !unlocked.isEmpty && !reduceMotion { SparkleBurst() }
                Circle().fill(Theme.sky).frame(width: 200, height: 200)
                if unlocked.isEmpty {
                    Text("🌍").font(.system(size: 90))
                } else {
                    Text(unlocked.compactMap { ContentLibrary.country($0)?.flag }.joined(separator: " "))
                        .font(.system(size: unlocked.count > 3 ? 40 : 60))
                        .multilineTextAlignment(.center)
                        .frame(width: 180)
                }
            }
            .scaleEffect(shown ? 1 : 0.5)

            VStack(spacing: 8) {
                Text("\(correct) of \(total) correct")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                Label("+\(points) points", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10).padding(.horizontal, 18)
                    .background(Theme.gold.opacity(0.25), in: Capsule())
            }

            Spacer()

            Button("Great!", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.35)) { shown = true } }
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

// MARK: - Landmarks (visiting an unlocked country)

struct LandmarkGalleryView: View {
    let country: QuizCountry
    let landmarks: [Landmark]

    @State private var index = 0

    var body: some View {
        VStack(spacing: 20) {
            let landmark = landmarks[index]

            IllustrationView(art: landmark.art, emojiSize: 130)
                .frame(maxWidth: 520)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        Text(country.flag)
                        Text(country.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 14)
                    .background(Theme.card, in: Capsule())
                    .padding(16)
                }
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                .padding(.horizontal, 24)
                .id(landmark.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

            VStack(alignment: .leading, spacing: 8) {
                Text(landmark.name)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(landmark.description)
                    .font(.body)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 24)
            .id("text-\(landmark.id)")
            .transition(.opacity)

            Spacer(minLength: 0)

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
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
        .animation(.spring(duration: 0.4), value: index)
    }

    private func pagerButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 56, height: 56)
                .background(Theme.card, in: Circle())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.primary : Theme.ink.opacity(0.25))
        .disabled(!enabled)
    }
}
