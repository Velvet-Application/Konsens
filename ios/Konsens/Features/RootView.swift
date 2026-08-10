import SwiftUI
import LocalAuthentication

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var unlocked = false
    @State private var biometricAttempted = false

    var body: some View {
        ZStack {
            Color.konsensBackground.ignoresSafeArea()
            if store.isLoading {
                ProgressView().tint(Color.konsensGreen)
            } else if !store.isAuthenticated {
                AuthView()
            } else if !store.onboardingComplete {
                NativeOnboardingView()
            } else if !unlocked {
                LockedView(unlock: unlock)
            } else {
                cockpit
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.caption.bold())
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.09)))
                        .padding(.bottom, 98)
                }.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated { unlocked = false; biometricAttempted = false }
        }
        .task {
            if store.isAuthenticated && store.onboardingComplete && !biometricAttempted { unlock() }
        }
    }

    private var cockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth: ArenaView()
                case .play: MarketsView()
                case .invest: LeagueView()
                case .learn: LearningView()
                case .profile: ProfileView()
                }
            }
            VStack(spacing: 0) {
                FloatingHeader()
                Spacer()
                FloatingDock()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private func unlock() {
        biometricAttempted = true
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            unlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Déverrouiller ton patrimoine Konsens") { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct FloatingHeader: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack {
            KonsensMark(compact: true)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
            Spacer()
            Button { store.selectedTab = .profile } label: {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.subscriptionTier == "premium" ? "PREMIUM" : "PATRIMOINE")
                        .font(.system(size: 7, weight: .bold)).tracking(1)
                        .foregroundStyle(Color.konsensMuted)
                    HStack(spacing: 5) {
                        Text(store.wealth.total.formatted(.number.precision(.fractionLength(0))))
                            .font(.subheadline.monospacedDigit().bold())
                        Text("Koins").font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                        Text(String(format: "%+.1f%%", store.wealth.performance))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
            }.buttonStyle(.plain)
        }
    }
}

private struct FloatingDock: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { withAnimation(.easeOut(duration: 0.2)) { store.selectedTab = tab } } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 16, weight: .semibold))
                        Text(tab.title).font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundStyle(store.selectedTab == tab ? Color.konsensGreen : Color.konsensMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(store.selectedTab == tab ? Color.konsensGreen.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }
}

private struct LockedView: View {
    let unlock: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            KonsensMark()
            Image(systemName: "faceid").font(.system(size: 52)).foregroundStyle(Color.konsensGreen)
            Text("Ton patrimoine est verrouillé").font(.title2.bold())
            Text("Utilise Face ID pour retrouver tes Koins, tes investissements et tes prédictions.")
                .multilineTextAlignment(.center).foregroundStyle(Color.konsensMuted).font(.subheadline)
            Button("Déverrouiller avec Face ID", action: unlock)
                .font(.headline).foregroundStyle(Color.konsensBackground)
                .padding(.horizontal, 20).padding(.vertical, 13)
                .background(Color.konsensGreen, in: Capsule())
        }.padding(30)
    }
}

private struct LearningView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: LearningLesson?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "KONSENS ACADEMY")
                Text("Comprendre avant de risquer.").font(.largeTitle.bold())
                Text("Des cours courts reliés aux décisions que tu prends dans ton portefeuille.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted).padding(.bottom, 8)
                ForEach(Array(store.lessons.enumerated()), id: \.element.id) { index, lesson in
                    Button { selected = lesson } label: {
                        HStack(spacing: 14) {
                            Text(String(format: "%02d", index + 1)).font(.title2.monospacedDigit().bold()).foregroundStyle(Color.konsensGreen.opacity(0.5))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("+\(lesson.xpReward) XP · 5 MIN").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.konsensGreen)
                                Text(lesson.title).font(.headline)
                                Text(lesson.summary).font(.caption).foregroundStyle(Color.konsensMuted).lineLimit(2)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.konsensGreen)
                        }.panel()
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .sheet(item: $selected) { lesson in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "COURS · +\(lesson.xpReward) XP")
                    Text(lesson.title).font(.largeTitle.bold())
                    Text(lesson.summary).foregroundStyle(Color.konsensMuted)
                    Text(lesson.concept).font(.body).lineSpacing(5).padding().background(Color.konsensPanel, in: RoundedRectangle(cornerRadius: 18))
                    Button("J’ai compris") { selected = nil }
                        .font(.headline).foregroundStyle(Color.konsensBackground).frame(maxWidth: .infinity).padding(14)
                        .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 15))
                }.padding(24)
            }.presentationDetents([.medium, .large]).presentationBackground(Color.konsensBackground)
        }
    }
}
