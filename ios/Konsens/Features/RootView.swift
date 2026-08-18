import SwiftUI
import LocalAuthentication

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @State private var unlocked = false
    @State private var biometricAttempted = false

    var body: some View {
        ZStack {
            WorldBackdrop(tab: store.selectedTab).ignoresSafeArea()
            if store.isLoading { ProgressView().tint(Color.konsensGreen) }
            else if !store.isAuthenticated { AuthView() }
            else if !store.onboardingComplete { NativeOnboardingView() }
            else if !unlocked { LockedView(unlock: unlock) }
            else { cockpit }
            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.09)))
                        .padding(.bottom, 98)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.32), value: store.selectedTab)
        .onChange(of: store.isAuthenticated) { _, authenticated in
            if !authenticated { unlocked = false; biometricAttempted = false; notifications.stop() }
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

    private var cockpit: some View {
        ZStack {
            Group {
                switch store.selectedTab {
                case .wealth: ArenaView()
                case .play: MarketsView()
                case .invest: LeagueView()
                case .learn: AcademyNativeView()
                case .profile: ProfileView()
                }
            }
            VStack(spacing: 0) {
                FloatingHeader(notifications: notifications)
                LearningSpine(tab: store.selectedTab)
                    .padding(.top, 7)
                Spacer()
                FloatingDock()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private func route(_ url: URL) {
        let destination = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        switch destination {
        case "play": store.selectedTab = .play
        case "invest", "finance": store.selectedTab = .invest
        case "learn", "academy": store.selectedTab = .learn
        case "profile", "notifications", "blockchain": store.selectedTab = .profile
        default: store.selectedTab = .wealth
        }
    }

    private func unlock() {
        biometricAttempted = true
        let context = LAContext()
        context.localizedCancelTitle = "Plus tard"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { unlocked = true; return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Déverrouiller ton patrimoine Konsens") { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct WorldBackdrop: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            base
            LinearGradient(
                colors: [Color.konsensGreen.opacity(tab == .wealth || tab == .profile ? 0.06 : 0.035), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            if tab == .play {
                RadialGradient(colors: [Color.konsensViolet.opacity(0.26), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color.konsensGreen.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 360)
                Circle().stroke(Color.konsensViolet.opacity(0.12), lineWidth: 1).frame(width: 310, height: 310).offset(x: 180, y: -320)
                Circle().stroke(Color.konsensGreen.opacity(0.08), lineWidth: 1).frame(width: 220, height: 220).offset(x: 150, y: -290)
            } else if tab == .invest {
                FinanceGrid().opacity(0.48)
                LinearGradient(colors: [Color.konsensBlue.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if tab == .learn {
                RadialGradient(colors: [Color.konsensGold.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 360)
                RadialGradient(colors: [Color(red: 0.25, green: 0.48, blue: 0.39).opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 300)
            }
        }
    }

    private var base: Color {
        switch tab {
        case .play: Color(red: 0.035, green: 0.027, blue: 0.075)
        case .invest: Color(red: 0.018, green: 0.035, blue: 0.047)
        case .learn: Color(red: 0.039, green: 0.055, blue: 0.045)
        default: Color.konsensBackground
        }
    }
}

private struct FinanceGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 34
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.konsensBlue.opacity(0.08)), lineWidth: 0.5)
        }
    }
}

private struct FloatingHeader: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        HStack(spacing: 8) {
            KonsensMark(compact: true)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: headerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: headerRadius).stroke(accent.opacity(0.16)))
            Text(universeName)
                .font(.system(size: 7, weight: .black, design: store.selectedTab == .invest ? .monospaced : .rounded))
                .tracking(1.1)
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(accent.opacity(0.08), in: Capsule())
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
                            .background(Color.konsensViolet, in: Circle())
                            .offset(x: 13, y: -13)
                    }
                }
            }
            .buttonStyle(.plain)
            Button { store.selectedTab = .profile } label: {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.subscriptionTier == "premium" ? "PREMIUM" : "PATRIMOINE")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.konsensMuted)
                    HStack(spacing: 5) {
                        Text(String(format: "%.0f", store.wealth.total))
                            .font(.subheadline.monospacedDigit().bold())
                        Text("Koins").font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                        Text(String(format: "%+.1f%%", store.wealth.performance))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: headerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: headerRadius).stroke(accent.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
    }

    private var accent: Color {
        switch store.selectedTab {
        case .play: Color.konsensViolet
        case .invest: Color.konsensBlue
        case .learn: Color.konsensGold
        default: Color.konsensGreen
        }
    }

    private var universeName: String {
        switch store.selectedTab {
        case .play: "PLAY"
        case .invest: "FINANCE"
        case .learn: "ACADEMY"
        case .wealth, .profile: "KONSENS"
        }
    }

    private var headerRadius: CGFloat { store.selectedTab == .invest ? 10 : 16 }
}

private struct LearningSpine: View {
    let tab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.konsensGreen)
                .frame(width: 34, height: 2)
                .shadow(color: Color.konsensGreen.opacity(0.65), radius: 5)
            Text(copy)
                .font(.system(size: 6, weight: .black, design: tab == .invest ? .monospaced : .rounded))
                .tracking(0.75)
                .foregroundStyle(Color.konsensGreen.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .accessibilityLabel("Fil conducteur : \(copy)")
    }

    private var copy: String {
        switch tab {
        case .play: "TESTER UNE INTUITION → COMPRENDRE LE RISQUE"
        case .invest: "OBSERVER → SIMULER → MESURER LE RISQUE"
        case .learn: "APPRENDRE → TESTER → PROGRESSER"
        case .wealth: "VOIR → COMPRENDRE → DÉCIDER"
        case .profile: "TA PROGRESSION FINANCIÈRE"
        }
    }
}

private struct FloatingDock: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.konsensGreen.opacity(0.75)).frame(height: 2).padding(.horizontal, 12)
            HStack(spacing: 3) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { store.selectedTab = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol).font(.system(size: 16, weight: .semibold))
                            Text(tab.title).font(.system(size: 7, weight: .semibold))
                        }
                        .foregroundStyle(store.selectedTab == tab ? activeAccent : Color.konsensMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(store.selectedTab == tab ? activeAccent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 8 : 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22).stroke(activeAccent.opacity(0.15)))
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }

    private var activeAccent: Color {
        switch store.selectedTab {
        case .play: Color.konsensViolet
        case .invest: Color.konsensBlue
        case .learn: Color.konsensGold
        default: Color.konsensGreen
        }
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
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.konsensMuted)
                .font(.subheadline)
            Button("Déverrouiller avec Face ID", action: unlock)
                .font(.headline)
                .foregroundStyle(Color.konsensBackground)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Color.konsensGreen, in: Capsule())
        }
        .padding(30)
    }
}
