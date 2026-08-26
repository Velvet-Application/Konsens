import SwiftUI
import LocalAuthentication

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @State private var unlocked = false
    @State private var biometricAttempted = false

    var body: some View {
        ZStack {
            GameWorldBackdrop(tab: store.selectedTab).ignoresSafeArea()

            if store.isLoading {
                ProgressView().tint(Color.konsensGold)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.09)))
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.24), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated {
                unlocked = false
                biometricAttempted = false
                notifications.stop()
            }
        }
        .onOpenURL { route($0) }
        .task {
            if store.isAuthenticated && store.onboardingComplete {
                notifications.start(store: store)
                WatchBridge.shared.start()
                if !biometricAttempted { unlock() }
            }
        }
    }

    @ViewBuilder
    private var cockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth: ArenaView()
                case .play: GamePlayView()
                case .invest: GameInvestView()
                case .league: LeagueSocialView()
                case .learn: AcademyNativeView()
                case .profile: ProfileView()
                }
            }

            VStack(spacing: 0) {
                GameHeader(notifications: notifications)
                GameRibbon().padding(.top, 7)
                Spacer()
                GameDock()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private func route(_ url: URL) {
        let destination = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        switch destination {
        case "play", "bet": store.selectedTab = .play
        case "invest", "finance": store.selectedTab = .invest
        case "league": store.selectedTab = .league
        case "profile", "notifications", "blockchain": store.selectedTab = .profile
        case "learn", "academy": store.selectedTab = .learn
        default: store.selectedTab = .wealth
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
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Retrouver tes Koins et ta ligue"
        ) { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct GameWorldBackdrop: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            Color.konsensBackground
            RadialGradient(colors: [accent.opacity(0.34), .clear], center: .topTrailing, startRadius: 0, endRadius: 470)
            RadialGradient(colors: [Color.konsensPink.opacity(0.12), .clear], center: .centerLeading, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Color.konsensGold.opacity(0.09), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 320)

            Circle().stroke(accent.opacity(0.08), lineWidth: 1).frame(width: 330, height: 330).offset(x: 180, y: -340)
            Circle().stroke(Color.konsensGold.opacity(0.06), lineWidth: 1).frame(width: 220, height: 220).offset(x: -170, y: 330)
        }
    }

    private var accent: Color {
        switch tab {
        case .wealth: return Color.konsensViolet
        case .play: return Color.konsensPink
        case .invest: return Color.konsensBlue
        case .league: return Color.konsensGold
        case .learn: return Color.konsensGreen
        case .profile: return Color.konsensViolet
        }
    }
}

private struct GameHeader: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        HStack(spacing: 8) {
            Button { store.selectedTab = .wealth } label: {
                HStack(spacing: 8) {
                    Image("KonsensLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 31, height: 31)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("KONSENS")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(Color.konsensGold)
                        Text("@\(store.username)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.konsensMuted)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            Button { store.selectedTab = .profile } label: {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.konsensMuted)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                    if notifications.unreadCount > 0 {
                        Text("\(min(notifications.unreadCount, 9))")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 15, height: 15)
                            .background(Color.konsensPink, in: Circle())
                            .offset(x: 13, y: -13)
                    }
                }
            }
            .buttonStyle(.plain)

            Button { store.selectedTab = .profile } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(Color.konsensGold)
                    Text(String(format: "%.0f K", store.wealth.total))
                        .font(.subheadline.monospacedDigit().black())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.konsensGold.opacity(0.16)))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GameRibbon: View {
    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(Color.konsensPink).frame(width: 28, height: 2)
            Text("KOINS · PARIS · INVEST · LIGUE")
                .font(.system(size: 7, weight: .black, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(Color.konsensGold)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }
}

private struct GameDock: View {
    @EnvironmentObject private var store: AppStore
    private let tabs = AppTab.gameTabs

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.konsensViolet.opacity(0.75)).frame(height: 2).padding(.horizontal, 12)
            HStack(spacing: 3) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { store.selectedTab = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: symbol(for: tab)).font(.system(size: 16, weight: .semibold))
                            Text(title(for: tab)).font(.system(size: 7, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(store.selectedTab == tab ? accent(for: tab) : Color.konsensMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(store.selectedTab == tab ? accent(for: tab).opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }

    private func title(for tab: AppTab) -> String {
        switch tab {
        case .wealth: "Jouer"
        case .play: "Paris"
        case .invest: "Invest"
        case .league: "Ligue"
        case .profile: "Moi"
        case .learn: "Learn"
        }
    }

    private func symbol(for tab: AppTab) -> String {
        switch tab {
        case .wealth: "gamecontroller.fill"
        case .play: "bolt.fill"
        case .invest: "chart.line.uptrend.xyaxis"
        case .league: "trophy.fill"
        case .profile: "person.crop.circle.fill"
        case .learn: "book.closed.fill"
        }
    }

    private func accent(for tab: AppTab) -> Color {
        switch tab {
        case .wealth: return Color.konsensGreen
        case .play: return Color.konsensPink
        case .invest: return Color.konsensBlue
        case .league: return Color.konsensGold
        case .profile: return Color.konsensViolet
        case .learn: return Color.konsensGreen
        }
    }
}

private struct LockedView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            KonsensMark()
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(Color.konsensGold)
            Text("Ton coffre est verrouillé")
                .font(.title2.black())
            Text("Face ID protège tes Koins, tes paris et ta ligue.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.konsensMuted)
                .font(.subheadline)
            Button("OUVRIR MON COFFRE", action: unlock)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.konsensBackground)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Color.konsensGold, in: Capsule())
        }
        .padding(30)
    }
}
