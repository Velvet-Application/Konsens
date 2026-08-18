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
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.32), value: store.selectedTab)
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

            VStack(spacing: 6) {
                FloatingHeader(notifications: notifications)
                LearningThreadBar(tab: store.selectedTab)
                Spacer()
                FloatingDock()
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 8)
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
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            unlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Déverrouiller ton parcours Konsens") { success, _ in
            DispatchQueue.main.async { unlocked = success }
        }
    }
}

private struct WorldBackdrop: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            base
            switch tab {
            case .play:
                PlayCircuitBackdrop()
            case .invest:
                FinanceGrid().opacity(0.58)
                LinearGradient(
                    colors: [Color.konsensBlue.opacity(0.10), .clear, Color.konsensGreen.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .learn:
                AcademyBackdrop()
            case .wealth, .profile:
                RadialGradient(colors: [Color.konsensGreen.opacity(0.09), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
            }
        }
    }

    private var base: Color {
        switch tab {
        case .play: return Color(red: 0.033, green: 0.022, blue: 0.073)
        case .invest: return Color(red: 0.014, green: 0.029, blue: 0.040)
        case .learn: return Color(red: 0.033, green: 0.065, blue: 0.047)
        default: return Color.konsensBackground
        }
    }
}

private struct PlayCircuitBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.konsensViolet.opacity(0.30), .clear], center: .topTrailing, startRadius: 0, endRadius: 430)
            RadialGradient(colors: [Color.konsensGreen.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 380)
            Canvas { context, size in
                var grid = Path()
                let step: CGFloat = 42
                var x: CGFloat = 0
                while x < size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y < size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(grid, with: .color(Color.konsensViolet.opacity(0.055)), lineWidth: 0.5)
            }
            Circle().stroke(Color.konsensViolet.opacity(0.14), lineWidth: 1).frame(width: 320, height: 320).offset(x: 190, y: -330)
            Circle().stroke(Color.konsensGreen.opacity(0.09), lineWidth: 1).frame(width: 230, height: 230).offset(x: 150, y: -290)
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
            context.stroke(path, with: .color(Color.konsensBlue.opacity(0.075)), lineWidth: 0.5)
        }
    }
}

private struct AcademyBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.konsensGreen.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 370)
            RadialGradient(colors: [Color.konsensGold.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 320)
            Canvas { context, size in
                for row in 0..<14 {
                    for col in 0..<9 {
                        let point = CGPoint(x: CGFloat(col) * 48 + 12, y: CGFloat(row) * 58 + 18)
                        let rect = CGRect(x: point.x, y: point.y, width: 3, height: 3)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.025)))
                    }
                }
            }
        }
    }
}

private struct LearningThreadBar: View {
    let tab: AppTab

    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(Color.konsensGreen).frame(width: 26, height: 3)
            Text(message)
                .font(.system(size: 6.5, weight: .black, design: tab == .invest ? .monospaced : .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.konsensGreen)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.konsensGreen.opacity(0.035), in: Capsule())
        .allowsHitTesting(false)
    }

    private var message: String {
        switch tab {
        case .play: return "PRÉDIRE · MESURER SA CONFIANCE · ACCEPTER DE SE TROMPER"
        case .invest: return "OBSERVER · MESURER LE RISQUE · DÉCIDER"
        case .learn: return "COMPRENDRE · PRATIQUER · MAÎTRISER"
        case .wealth: return "CHAQUE JOUR, ENTRAÎNE TA CAPACITÉ À MIEUX DÉCIDER AVEC L’ARGENT"
        case .profile: return "MESURE TES PROGRÈS, PAS SEULEMENT TES GAINS"
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
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(accent.opacity(0.08), in: Capsule())

            Spacer()

            Button { store.selectedTab = .profile } label: {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13)).foregroundStyle(Color.konsensMuted)
                        .frame(width: 36, height: 36).background(.ultraThinMaterial, in: Circle())
                    if notifications.unreadCount > 0 {
                        Text("\(min(notifications.unreadCount, 9))")
                            .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                            .frame(width: 15, height: 15).background(Color.konsensViolet, in: Circle())
                            .offset(x: 13, y: -13)
                    }
                }
            }.buttonStyle(.plain)

            Button { store.selectedTab = .profile } label: {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.subscriptionTier == "premium" ? "PREMIUM" : "PARCOURS")
                        .font(.system(size: 7, weight: .bold)).tracking(1).foregroundStyle(Color.konsensMuted)
                    HStack(spacing: 5) {
                        Text(store.wealth.total.formatted(.number.precision(.fractionLength(0))))
                            .font(.subheadline.monospacedDigit().bold())
                        Text("K").font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                        Text(String(format: "%+.1f%%", store.wealth.performance))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: headerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: headerRadius).stroke(accent.opacity(0.14)))
            }.buttonStyle(.plain)
        }
    }

    private var accent: Color {
        switch store.selectedTab {
        case .play: return Color.konsensViolet
        case .invest: return Color.konsensBlue
        case .learn: return Color.konsensGreen
        default: return Color.konsensGreen
        }
    }

    private var universeName: String {
        switch store.selectedTab {
        case .play: return "PLAY"
        case .invest: return "INVESTIR"
        case .learn: return "APPRENDRE"
        case .wealth: return "AUJOURD’HUI"
        case .profile: return "PROFIL"
        }
    }

    private var headerRadius: CGFloat { store.selectedTab == .invest ? 10 : 16 }
}

private struct FloatingDock: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
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
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(store.selectedTab == tab ? activeAccent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 8 : 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: store.selectedTab == .invest ? 14 : 22).stroke(activeAccent.opacity(0.15)))
        .overlay(alignment: .top) {
            Capsule().fill(Color.konsensGreen).frame(width: 94, height: 2).offset(y: -1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 26, y: 14)
    }

    private var activeAccent: Color {
        switch store.selectedTab {
        case .play: return Color.konsensViolet
        case .invest: return Color.konsensBlue
        case .learn: return Color.konsensGreen
        default: return Color.konsensGreen
        }
    }
}

private struct LockedView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            KonsensMark()
            Image(systemName: "faceid").font(.system(size: 52)).foregroundStyle(Color.konsensGreen)
            Text("Ton parcours est verrouillé").font(.title2.bold())
            Text("Utilise Face ID pour retrouver tes Koins, tes décisions et ta progression.")
                .multilineTextAlignment(.center).foregroundStyle(Color.konsensMuted).font(.subheadline)
            Button("Déverrouiller avec Face ID", action: unlock)
                .font(.headline).foregroundStyle(Color.konsensBackground)
                .padding(.horizontal, 20).padding(.vertical, 13)
                .background(Color.konsensGreen, in: Capsule())
        }
        .padding(30)
    }
}