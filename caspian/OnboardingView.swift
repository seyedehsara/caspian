import SwiftUI

/// Shown once, on first launch. No account, no sign-in: the player just starts.
struct OnboardingView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var floating = false

    var body: some View {
        ZStack {
            SoftBackground()

            VStack(spacing: 0) {
                Spacer()
                Group {
                    if page == 0 { welcomePage } else { mascotPage }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer()

                Button(page == 0 ? "Get Started" : "Let's go") {
                    if page == 0 {
                        withAnimation(.spring(duration: 0.5)) { page = 1 }
                    } else {
                        progress.hasOnboarded = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            VStack(spacing: -6) {
                Text("Caspian")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primary)
                Image(systemName: "face.smiling")
                    .font(.title)
                    .foregroundStyle(Theme.primary)
                    .offset(y: -4)
            }
            Text("Discover the world,\none question at a time!")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink.opacity(0.75))

            ZStack {
                Text("🌍")
                    .font(.system(size: 150))
                    .shadow(color: Theme.primary.opacity(0.25), radius: 30, y: 20)
                    .offset(y: floating ? -10 : 10)
                Image(systemName: "airplane")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.primary)
                    .rotationEffect(.degrees(-30))
                    .offset(x: floating ? 120 : 100, y: floating ? -110 : -90)
                Image(systemName: "sparkle")
                    .foregroundStyle(Theme.gold)
                    .offset(x: -120, y: -60)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 32)
    }

    private var mascotPage: some View {
        VStack(spacing: 20) {
            Text("👩🏻")
                .font(.system(size: 120))
                .offset(y: floating ? -6 : 6)
            VStack(spacing: 10) {
                Text("Welcome to Caspian!")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Guess where each photo comes from. Every right answer unlocks that country on your globe.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
        }
        .padding(.horizontal, 32)
    }
}
