import SwiftUI

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Eyebrow(text: "TON LABORATOIRE FINANCIER")
                    Text("Bonjour \(store.username).")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Fais grandir ton patrimoine. Comprends chaque décision.")
                        .font(.subheadline).foregroundStyle(.konsensMuted)
                }
                WealthCard()
                RiskCard()
                HStack(spacing: 10) {
                    Shortcut(title: "Jouer", detail: "Tester ton instinct", icon: "play.fill", tint: .konsensViolet) { store.selectedTab = .play }
                    Shortcut(title: "Investir", detail: "Bâtir ton portefeuille", icon: "chart.line.uptrend.xyaxis", tint: .konsensGreen) { store.selectedTab = .invest }
                }
                Shortcut(title: "Apprendre", detail: "Comprendre avant de risquer · \(store.lessons.count) cours", icon: "book.fill", tint: .konsensBlue) { store.selectedTab = .learn }
                PremiumCard()
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
    }
}

private struct WealthCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "PATRIMOINE TOTAL")
                Spacer()
                Text(String(format: "%+.1f%%", store.wealth.performance))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(store.wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(store.wealth.total.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 43, weight: .bold, design: .rounded)).monospacedDigit()
                Text("Koins").font(.caption).foregroundStyle(.konsensMuted)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(height: 5)
                Capsule().fill(LinearGradient(colors: [.konsensGreen, .konsensBlue, .konsensViolet], startPoint: .leading, endPoint: .trailing)).frame(width: 165, height: 5)
            }
            HStack(spacing: 8) {
                WealthMini(title: "Disponible", value: store.wealth.cash)
                WealthMini(title: "Investi", value: store.wealth.investments)
                WealthMini(title: "Paris", value: store.wealth.bets)
            }
            Text("Départ : 1 000 Koins · aucune valeur monétaire")
                .font(.system(size: 8)).foregroundStyle(.konsensMuted)
        }.panel()
    }
}

private struct WealthMini: View {
    let title: String; let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(.konsensMuted)
            Text(value.formatted(.number.precision(.fractionLength(0)))).font(.subheadline.monospacedDigit().bold())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RiskCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled").foregroundStyle(.konsensGold).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Gagner vite signifie aussi pouvoir perdre vite.").font(.subheadline.bold())
                Text("Konsens rend le risque visible avec des Koins fictifs, jamais achetables ni convertibles en argent.").font(.caption).foregroundStyle(.konsensMuted)
            }
        }.padding(16).background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensGold.opacity(0.15)))
    }
}

private struct Shortcut: View {
    let title: String; let detail: String; let icon: String; let tint: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.headline).foregroundStyle(tint).frame(width: 40, height: 40).background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(detail).font(.system(size: 9)).foregroundStyle(.konsensMuted) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(tint)
            }.panel()
        }.buttonStyle(.plain)
    }
}

private struct PremiumCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "crown.fill").foregroundStyle(.konsensViolet)
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "KONSENS PREMIUM")
                Text(store.subscriptionTier == "premium" ? "Premium actif" : "4,99 € / mois").font(.headline)
                Text("Sans pub · prédictif · détails des portefeuilles · futurs flux financiers API").font(.system(size: 9)).foregroundStyle(.konsensMuted)
            }
            Spacer()
        }.padding(18).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensViolet.opacity(0.2)))
    }
}
