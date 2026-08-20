import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var notifications = NotificationManager.shared
    @ObservedObject private var privacy = KonsensPrivacyConsentManager.shared
    @AppStorage("konsens_finance_pro_enabled") private var financeProEnabled = false
    @State private var showNetwork = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                profileHero
                gameStats
                experienceCard
                academyCard
                notificationsCard
                transparencyCard
                privacyCard
                securityCard

                Button(role: .destructive) {
                    Task { await store.signOut() }
                } label: {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.konsensNegative)
                .background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.horizontal, 18)
            .padding(.top, 104)
            .padding(.bottom, 112)
        }
        .sheet(isPresented: $showNetwork) {
            NetworkView().environmentObject(store)
        }
        .onChange(of: store.subscriptionTier) { _, tier in
            if tier != "premium" { financeProEnabled = false }
        }
    }

    private var profileHero: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.konsensViolet, Color.konsensGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Text(String(store.username.prefix(1)).uppercased())
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.konsensViolet.opacity(0.35), radius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.subscriptionTier == "premium" ? "KONSENS PREMIUM" : "KONSENS PLAYER")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(store.subscriptionTier == "premium" ? Color.konsensGold : Color.konsensGreen)
                Text("@\(store.username)")
                    .font(.title2.bold())
                Text(String(format: "%.0f Koins de patrimoine", store.wealth.total))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.konsensMuted)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.konsensPanelRaised.opacity(0.96), in: RoundedRectangle(cornerRadius: 23))
    }

    private var gameStats: some View {
        HStack(spacing: 9) {
            stat("DISPO", String(format: "%.0f K", store.wealth.cash), Color.konsensGold)
            stat("INVESTI", String(format: "%.0f K", store.wealth.investments), Color.konsensBlue)
            stat("PARIS", String(format: "%.0f K", store.wealth.bets), Color.konsensViolet)
        }
    }

    private var experienceCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EXPÉRIENCE KONSENS")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.konsensGreen)
                    Text("Choisis ton interface")
                        .font(.headline.bold())
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.konsensGreen)
            }

            modeRow(
                icon: "gamecontroller.fill",
                title: "Mode Jeu",
                detail: "Challenges, ligue, classement, Koins",
                selected: !financeProEnabled,
                color: Color.konsensViolet
            ) {
                financeProEnabled = false
                store.selectedTab = .wealth
            }

            modeRow(
                icon: "chart.xyaxis.line",
                title: "Mode Finance Pro",
                detail: store.subscriptionTier == "premium" ? "Graphiques, API, blockchain, Academy" : "Réservé aux membres Premium",
                selected: financeProEnabled && store.subscriptionTier == "premium",
                color: Color.konsensBlue
            ) {
                guard store.subscriptionTier == "premium" else {
                    store.showToast("Le Mode Finance Pro est réservé aux Premium")
                    return
                }
                financeProEnabled = true
                store.selectedTab = .wealth
            }

            if store.subscriptionTier != "premium" {
                Button {
                    Task { await store.startPremiumTrial() }
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("TESTER PREMIUM 14 JOURS")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.bold())
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(17)
        .background(
            LinearGradient(colors: [Color.konsensGreen.opacity(0.07), Color.konsensPanelRaised], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensGreen.opacity(0.13)))
    }

    private var academyCard: some View {
        Button {
            store.selectedTab = .learn
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundStyle(Color.konsensGreen)
                    .frame(width: 46, height: 46)
                    .background(Color.konsensGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACADEMY")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensGreen)
                    Text("Comprendre pourquoi tu gagnes… ou perds")
                        .font(.subheadline.bold())
                    Text("Cours, quiz et progression restent accessibles depuis ton profil.")
                        .font(.caption2)
                        .foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.konsensGreen)
            }
            .padding(16)
            .background(Color.konsensGreen.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KONSENS LIVE")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensViolet)
                    Text("Push & provocations de ligue").font(.headline)
                }
                Spacer()
                Text("\(notifications.unreadCount)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.konsensViolet)
            }

            Text("Dépassements au classement, bons coups, challenges qui ferment et mouvements importants peuvent te ramener dans le jeu.")
                .font(.caption)
                .foregroundStyle(Color.konsensMuted)

            if notifications.authorization != .authorized {
                Button {
                    Task { await notifications.requestPermission(store: store) }
                } label: {
                    Label("Activer les notifications iOS", systemImage: "bell.badge.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.konsensBackground)
                .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 13))
            }
        }
        .panel()
    }

    private var transparencyCard: some View {
        Button { showNetwork = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.konsensBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.konsensBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRANSPARENCY")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.konsensBlue)
                    Text("Blockchain & données réelles").font(.headline)
                    Text("La couche sérieuse reste disponible pour comprendre ce qui se passe derrière le jeu.")
                        .font(.caption2)
                        .foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.konsensBlue)
            }
            .panel()
        }
        .buttonStyle(.plain)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CONFIDENTIALITÉ & PUBLICITÉ")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(Color.konsensGreen)
                    Text("Tes choix publicitaires")
                        .font(.headline)
                }
                Spacer()
                Image(systemName: privacy.canRequestAds ? "checkmark.shield.fill" : "hand.raised.fill")
                    .foregroundStyle(privacy.canRequestAds ? Color.konsensGreen : Color.konsensGold)
            }

            Text(privacy.canRequestAds
                 ? "Les demandes publicitaires respectent l’état de consentement Google UMP."
                 : "Konsens ne charge pas de publicité tant que la plateforme de consentement ne l’autorise pas.")
                .font(.caption)
                .foregroundStyle(Color.konsensMuted)

            if privacy.isPrivacyOptionsRequired {
                Button {
                    Task {
                        do {
                            try await privacy.presentPrivacyOptions()
                        } catch {
                            store.showToast("Options de confidentialité indisponibles")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("GÉRER MES CHOIX PUBLICITAIRES")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.bold())
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }

            if let message = privacy.lastError, !message.isEmpty {
                Text("Consentement : \(message)")
                    .font(.caption2)
                    .foregroundStyle(Color.konsensGold)
            }
        }
        .panel()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SÉCURITÉ")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(Color.konsensMuted)
            Label("Face ID protège l’accès à ton compte", systemImage: "faceid")
                .font(.subheadline.bold())
            Text("Les Koins sont fictifs, non achetables et non convertibles en argent. Ton patrimoine Konsens est un score de jeu.")
                .font(.caption)
                .foregroundStyle(Color.konsensMuted)
        }
        .panel()
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }

    private func modeRow(icon: String, title: String, detail: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(detail).font(.caption2).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.konsensGreen : Color.konsensMuted)
            }
            .padding(12)
            .background(selected ? Color.konsensGreen.opacity(0.055) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}
