import SwiftUI

struct LeagueView: View {
    @EnvironmentObject private var store: AppStore
    @State private var amount = 100

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "INVESTISSEMENT")
                Text("Construis avant\nde risquer.").font(.largeTitle.bold())
                Text("\(store.credits.formatted()) Koins disponibles. Les valeurs ci-dessous sont des cotations d’entraînement, pas des cours réels.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted)
                AmountPicker(amount: $amount)
                ForEach(store.assets) { asset in AssetCard(asset: asset, amount: amount) }
                PremiumMarketsCard()
                RiskFooter()
            }.padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
    }
}

private struct AssetCard: View {
    @EnvironmentObject private var store: AppStore
    let asset: AssetQuote
    let amount: Int
    var body: some View {
        HStack(spacing: 13) {
            Text(String(asset.symbol.prefix(2)))
                .font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGreen)
                .frame(width: 46, height: 46).background(Color.konsensGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(asset.kind.uppercased()) · SIMULATION").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                Text(asset.name).font(.headline)
                Text("Valeur école \(asset.price, specifier: "%.2f")").font(.caption2).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
            Button { Task { await store.buyAsset(asset, amount: amount) } } label: {
                VStack(spacing: 2) { Image(systemName: "plus"); Text("\(amount)").font(.system(size: 8, weight: .bold)) }
                    .foregroundStyle(Color.konsensBackground).frame(width: 48, height: 48).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 14))
            }.disabled(store.credits < amount).opacity(store.credits < amount ? 0.35 : 1)
        }.panel()
    }
}

private struct PremiumMarketsCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet); Eyebrow(text: "PREMIUM · 4,99 € / MOIS") }
            Text("Du simulateur aux vrais marchés.").font(.title3.bold())
            Text("Flux financiers via API, tendances enrichies, prédictif et détail des portefeuilles publics. L’achat réel d’actifs reste hors de Konsens.")
                .font(.caption).foregroundStyle(Color.konsensMuted)
            Label(store.subscriptionTier == "premium" ? "Premium actif" : "Bientôt disponible", systemImage: store.subscriptionTier == "premium" ? "checkmark.seal.fill" : "lock.fill")
                .font(.caption.bold()).foregroundStyle(Color.konsensViolet)
        }.padding(20).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.2)))
    }
}
