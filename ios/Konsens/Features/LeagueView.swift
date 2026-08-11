import SwiftUI
import Charts

struct LeagueView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: AssetQuote?
    @State private var quote: LiveMarketQuote?
    @State private var amount = 100
    @State private var range = "1mo"
    @State private var positionQuantity = 0.0
    @State private var positionAverage = 0.0
    @State private var loadingQuote = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "PASSERELLE MARCHÉS · BÊTA LIVE")
                Text("Cours réels.\nArgent fictif.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("Les prix et historiques viennent d’un fournisseur de marché horodaté. Tes ordres restent exclusivement simulés en Koins : rien n’est envoyé à une bourse.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.assets) { asset in
                            Button { selected = asset } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(asset.symbol).font(.caption.bold())
                                    Text(asset.kind.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                                }
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(selected?.id == asset.id ? Color.konsensGreen.opacity(0.12) : Color.konsensPanel, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected?.id == asset.id ? Color.konsensGreen.opacity(0.35) : Color.white.opacity(0.06)))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                if let asset = selected {
                    LiveAssetPanel(asset: asset, quote: quote, positionQuantity: positionQuantity, positionAverage: positionAverage, loading: loadingQuote)
                    HStack(spacing: 5) {
                        ForEach(["1d","5d","1mo","6mo","1y","5y"], id: \.self) { item in
                            Button(item.uppercased()) { range = item }
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(range == item ? Color.konsensBackground : Color.konsensMuted)
                                .padding(.horizontal, 9).padding(.vertical, 7)
                                .background(range == item ? Color.konsensGreen : Color.white.opacity(0.035), in: Capsule())
                        }
                    }
                    AmountPicker(amount: $amount)
                    HStack(spacing: 8) {
                        Button { Task { await store.buyAsset(asset, amount: amount); await refreshPosition(asset); await refreshQuote(asset) } } label: {
                            Label("Acheter \(amount) K", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(13)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.konsensBackground).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 14))
                        .disabled(store.credits < amount).opacity(store.credits < amount ? 0.35 : 1)

                        Button { Task { await store.sellAsset(asset, amount: amount); await refreshPosition(asset); await refreshQuote(asset) } } label: {
                            Label("Revendre", systemImage: "minus.circle.fill").frame(maxWidth: .infinity).padding(13)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.konsensNegative).background(Color.konsensNegative.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                        .disabled(positionValue < Double(amount)).opacity(positionValue < Double(amount) ? 0.35 : 1)
                    }
                } else {
                    ContentUnavailableView("Marché en préparation", systemImage: "chart.xyaxis.line", description: Text("Les actifs connectés apparaîtront ici."))
                        .panel()
                }

                PremiumMarketsCard()
                RiskFooter()
            }.padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .task { if selected == nil { selected = store.assets.first } }
        .task(id: selected?.id) { if let asset = selected { await refreshQuote(asset); await refreshPosition(asset) } }
        .task(id: range) { if let asset = selected { await refreshQuote(asset) } }
        .refreshable { await store.refreshFinance(); if let asset = selected { await refreshQuote(asset); await refreshPosition(asset) } }
    }

    private var positionValue: Double { guard let quote else { return 0 }; return positionQuantity * quote.price }

    private func refreshQuote(_ asset: AssetQuote) async {
        loadingQuote = true
        quote = await store.liveQuote(for: asset, range: range)
        loadingQuote = false
    }

    private func refreshPosition(_ asset: AssetQuote) async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Row: Decodable { let quantity: Double; let average_price: Double }
        if let row: Row = try? await store.supabase.from("positions").select("quantity,average_price").eq("user_id", value: userID).eq("asset_id", value: asset.id).single().execute().value {
            positionQuantity = row.quantity; positionAverage = row.average_price
        } else { positionQuantity = 0; positionAverage = 0 }
    }
}

private struct LiveAssetPanel: View {
    let asset: AssetQuote
    let quote: LiveMarketQuote?
    let positionQuantity: Double
    let positionAverage: Double
    let loading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "\(asset.kind.uppercased()) · MARCHÉ CONNECTÉ")
                    Text(asset.name).font(.title2.bold())
                    Text(asset.symbol).font(.caption).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                if let quote {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(quote.price, specifier: "%.2f") \(quote.currency)").font(.title2.monospacedDigit().bold())
                        Text(String(format: "%+.2f%%", quote.changePct)).font(.caption.bold()).foregroundStyle(quote.changePct >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                } else if loading { ProgressView().tint(Color.konsensGreen) }
            }

            if let quote, quote.points.count > 1 {
                Chart(quote.points) { point in
                    LineMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(quote.changePct >= 0 ? Color.konsensGreen : Color.konsensNegative)
                    AreaMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                        .foregroundStyle(LinearGradient(colors: [(quote.changePct >= 0 ? Color.konsensGreen : Color.konsensNegative).opacity(0.18), Color.clear], startPoint: .top, endPoint: .bottom))
                }
                .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 180)
                Text("Dernière donnée : \(quote.updatedAt) · \(quote.provider)").font(.system(size: 7)).foregroundStyle(Color.konsensMuted)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("POSITION KONSENS").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                    Text(positionQuantity > 0 && quote != nil ? "\(positionQuantity * (quote?.price ?? 0), specifier: "%.0f") Koins" : "Aucune position").font(.headline.monospacedDigit())
                    if positionQuantity > 0 { Text("\(positionQuantity, specifier: "%.4f") unités · PRU \(positionAverage, specifier: "%.2f")").font(.caption2).foregroundStyle(Color.konsensMuted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SOURCE").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                    Text(quote?.exchange.isEmpty == false ? quote!.exchange : "Marché externe").font(.caption.bold())
                    Text("Aucun ordre réel transmis").font(.caption2).foregroundStyle(Color.konsensMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.panel()
    }
}

private struct PremiumMarketsCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet); Eyebrow(text: "PREMIUM · 4,99 € / MOIS") }
            Text(store.subscriptionTier == "premium" ? "Premium actif." : "Du cours à l’analyse.").font(.title3.bold())
            Text("Sans pub, historiques enrichis, suivi blockchain public et outils d’analyse avancés. Pendant la bêta, l’essai Premium est gratuit 14 jours ; aucun paiement n’est débité.")
                .font(.caption).foregroundStyle(Color.konsensMuted)
            if store.subscriptionTier == "premium" {
                Label("Publicité supprimée", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(Color.konsensPositive)
            } else {
                Button { Task { await store.startPremiumTrial() } } label: { Text("Activer 14 jours de Premium bêta").frame(maxWidth: .infinity).padding(12) }
                    .buttonStyle(.plain).foregroundStyle(.white).background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 14))
            }
        }.padding(20).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.2)))
    }
}
