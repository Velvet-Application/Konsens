import SwiftUI

struct MarketsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var amount = 100

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "PRÉDICTION")
                Text("Joue ton instinct.\nMesure le risque.").font(.largeTitle.bold())
                Text("Solde disponible : \(store.credits.formatted()) Koins. Un pari peut accélérer ton patrimoine comme l’amputer.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted)
                AmountPicker(amount: $amount)
                if store.markets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill").font(.largeTitle).foregroundStyle(Color.konsensGreen)
                        Text("Aucun marché vérifié ouvert").font(.headline)
                        Text("Les prédictions ne sont publiées qu’après validation de la question, de la source et de la règle de résolution.")
                            .font(.caption).foregroundStyle(Color.konsensMuted).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(30).panel()
                } else {
                    ForEach(store.markets) { market in MarketCard(market: market, amount: amount) }
                }
                RiskFooter()
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
    }
}

private struct MarketCard: View {
    @EnvironmentObject private var store: AppStore
    let market: Market
    let amount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Eyebrow(text: market.category.uppercased()); Spacer(); Text("\(market.yesProbability)% OUI").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensGreen) }
            Text(market.question).font(.headline)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Color.konsensPositive.frame(width: proxy.size.width * CGFloat(market.yesProbability) / 100)
                    Color.konsensNegative
                }.clipShape(Capsule())
            }.frame(height: 5)
            HStack { Text("Clôture \(shortDate(market.closesAt))").font(.caption2).foregroundStyle(Color.konsensMuted); Spacer(); Text("Mise \(amount) Koins").font(.caption2).foregroundStyle(Color.konsensMuted) }
            HStack(spacing: 9) {
                Button { Task { await store.bet(market, outcome: "yes", amount: amount) } } label: { Text("OUI · \(amount)").frame(maxWidth: .infinity).padding(13).background(Color.konsensPositive.opacity(0.12), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.konsensPositive.opacity(0.22))) }.foregroundStyle(Color.konsensPositive)
                Button { Task { await store.bet(market, outcome: "no", amount: amount) } } label: { Text("NON · \(amount)").frame(maxWidth: .infinity).padding(13).background(Color.konsensNegative.opacity(0.11), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.konsensNegative.opacity(0.2))) }.foregroundStyle(Color.konsensNegative)
            }.font(.subheadline.bold())
        }.panel()
    }

    private func shortDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct AmountPicker: View {
    @Binding var amount: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach([25, 50, 100, 250], id: \.self) { value in
                Button("\(value)") { amount = value }
                    .font(.caption.bold())
                    .foregroundStyle(amount == value ? Color.konsensBackground : Color.konsensMuted)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(amount == value ? Color.konsensGreen : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer(); Text("Koins").font(.caption2).foregroundStyle(Color.konsensMuted)
        }.padding(7).background(Color.konsensPanel, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
    }
}

struct RiskFooter: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(Color.konsensGold)
            Text("Risque visible, argent fictif. Une forte performance virtuelle peut être suivie d’une perte importante. Les Koins ne sont ni achetables, ni convertibles, ni retirable en argent.")
                .font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
        }.padding(14).background(Color.konsensGold.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}
