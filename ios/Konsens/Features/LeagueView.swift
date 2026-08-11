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
    @State private var showWatchedOnly = false

    private var visibleAssets: [AssetQuote] {
        showWatchedOnly ? store.assets.filter { store.watchedAssetIDs.contains($0.id) } : store.assets
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "KONSENS FINANCE · MARCHÉS CONNECTÉS")
                Text("Cours réels.\nArgent fictif.")
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .tracking(-1.5)
                Text("Observe, suis, compare puis investis seulement en simulation. Les prix et historiques viennent d’un fournisseur de marché horodaté ; aucun ordre n’est transmis à une bourse.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(3)

                FinanceCommandBar(showWatchedOnly: $showWatchedOnly, assetCount: store.assets.count, watchedCount: store.watchedAssetIDs.count, positionCount: 0) {
                    if showWatchedOnly, selected.map({ !store.watchedAssetIDs.contains($0.id) }) == true {
                        selected = visibleAssets.first
                    }
                }

                if showWatchedOnly && visibleAssets.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "star").font(.largeTitle).foregroundStyle(Color.konsensBlue)
                        Text("Aucun marché suivi").font(.headline.monospaced())
                        Text("Ajoute un actif à tes suivis. Il remontera ici et dans ton widget Finance.")
                            .font(.caption).multilineTextAlignment(.center).foregroundStyle(Color.konsensMuted)
                        Button("Explorer les marchés") { showWatchedOnly = false }
                            .font(.caption.bold()).foregroundStyle(Color.konsensBlue)
                    }.frame(maxWidth: .infinity).padding(28).financePanel()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(visibleAssets) { asset in
                                Button { selected = asset } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 5) {
                                            Text(asset.symbol).font(.caption.monospaced().bold())
                                            if store.watchedAssetIDs.contains(asset.id) { Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(Color.konsensBlue) }
                                        }
                                        Text(asset.kind.uppercased()).font(.system(size: 6, weight: .bold)).foregroundStyle(Color.konsensMuted)
                                    }
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                    .background(selected?.id == asset.id ? Color.konsensBlue.opacity(0.10) : Color(red: 0.026, green: 0.050, blue: 0.065), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected?.id == asset.id ? Color.konsensBlue.opacity(0.30) : Color.konsensBlue.opacity(0.08)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let asset = selected {
                    HStack {
                        Text("ACTIF SÉLECTIONNÉ").font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(Color.konsensBlue)
                        Spacer()
                        Button { Task { await store.toggleAssetWatch(asset) } } label: {
                            Label(store.watchedAssetIDs.contains(asset.id) ? "Suivi" : "Suivre", systemImage: store.watchedAssetIDs.contains(asset.id) ? "star.fill" : "star")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.konsensBlue.opacity(store.watchedAssetIDs.contains(asset.id) ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.konsensBlue.opacity(0.14)))
                        }.buttonStyle(.plain).foregroundStyle(store.watchedAssetIDs.contains(asset.id) ? Color.konsensBlue : Color.konsensMuted)
                    }

                    LiveAssetPanel(asset: asset, quote: quote, positionQuantity: positionQuantity, positionAverage: positionAverage, loading: loadingQuote)

                    HStack(spacing: 5) {
                        ForEach(["1d","5d","1mo","6mo","1y","5y"], id: \.self) { item in
                            Button(item.uppercased()) { range = item }
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(range == item ? Color.konsensBackground : Color.konsensMuted)
                                .padding(.horizontal, 9).padding(.vertical, 7)
                                .background(range == item ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }

                    AmountPicker(amount: $amount, accent: Color.konsensBlue)
                    HStack(spacing: 8) {
                        Button { Task { await store.buyAsset(asset, amount: amount); await refreshPosition(asset); await refreshQuote(asset) } } label: {
                            Label("Acheter \(amount) K", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(13)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.konsensBackground).background(Color.konsensBlue, in: RoundedRectangle(cornerRadius: 8))
                        .disabled(store.credits < amount).opacity(store.credits < amount ? 0.35 : 1)

                        Button { Task { await store.sellAsset(asset, amount: amount); await refreshPosition(asset); await refreshQuote(asset) } } label: {
                            Label("Revendre", systemImage: "minus.circle.fill").frame(maxWidth: .infinity).padding(13)
                        }
                        .buttonStyle(.plain).foregroundStyle(Color.konsensNegative).background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(positionValue < Double(amount)).opacity(positionValue < Double(amount) ? 0.35 : 1)
                    }
                } else if !showWatchedOnly {
                    ContentUnavailableView("Marché en préparation", systemImage: "chart.xyaxis.line", description: Text("Les actifs connectés apparaîtront ici."))
                        .financePanel()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "DISCIPLINE D’INVESTISSEMENT")
                    Text("Observer n’est pas investir.").font(.headline.monospaced())
                    Text("La watchlist te permet de suivre un actif sans prendre de position. Compare son évolution réelle à ton intuition avant d’engager des Koins.")
                        .font(.caption).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                }.financePanel()

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

private struct FinanceCommandBar: View {
    @Binding var showWatchedOnly: Bool
    let assetCount: Int
    let watchedCount: Int
    let positionCount: Int
    let changed: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 5) {
                Button("TOUS") { showWatchedOnly = false; changed() }
                    .financeFilter(active: !showWatchedOnly)
                Button("★ SUIVIS \(watchedCount)") { showWatchedOnly = true; changed() }
                    .financeFilter(active: showWatchedOnly)
                Spacer()
                Text("LIVE").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(Color.konsensBlue)
            }
            HStack {
                commandMetric("\(assetCount)", "ACTIFS")
                Spacer()
                commandMetric("\(watchedCount)", "SUIVIS")
                Spacer()
                commandMetric("\(positionCount)", "POSITIONS")
            }
        }.padding(10).background(Color(red: 0.022, green: 0.042, blue: 0.053), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensBlue.opacity(0.10)))
    }

    private func commandMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.monospacedDigit().bold())
            Text(label).font(.system(size: 5, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
        }
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
                    Text(asset.name).font(.title2.monospaced().bold())
                    Text(asset.symbol).font(.caption.monospaced()).foregroundStyle(Color.konsensMuted)
                }
                Spacer()
                if let quote {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(quote.price, specifier: "%.2f") \(quote.currency)").font(.title2.monospacedDigit().bold())
                        Text(String(format: "%+.2f%%", quote.changePct)).font(.caption.bold()).foregroundStyle(quote.changePct >= 0 ? Color.konsensPositive : Color.konsensNegative)
                    }
                } else if loading { ProgressView().tint(Color.konsensBlue) }
            }

            if let quote, quote.points.count > 1 {
                Chart(quote.points) { point in
                    LineMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(quote.changePct >= 0 ? Color.konsensBlue : Color.konsensNegative)
                    AreaMark(x: .value("Date", point.time), y: .value("Cours", point.price))
                        .foregroundStyle(LinearGradient(colors: [(quote.changePct >= 0 ? Color.konsensBlue : Color.konsensNegative).opacity(0.16), Color.clear], startPoint: .top, endPoint: .bottom))
                }
                .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 180)
                Text("Dernière donnée : \(quote.updatedAt) · \(quote.provider)").font(.system(size: 7, design: .monospaced)).foregroundStyle(Color.konsensMuted)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("POSITION KONSENS").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    Text(positionQuantity > 0 && quote != nil ? "\(positionQuantity * (quote?.price ?? 0), specifier: "%.0f") Koins" : "Aucune position").font(.headline.monospacedDigit())
                    if positionQuantity > 0 { Text("\(positionQuantity, specifier: "%.4f") unités · PRU \(positionAverage, specifier: "%.2f")").font(.caption2.monospaced()).foregroundStyle(Color.konsensMuted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SOURCE").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.konsensMuted)
                    Text(quote?.exchange.isEmpty == false ? quote!.exchange : "Marché externe").font(.caption.bold())
                    Text("Aucun ordre réel transmis").font(.caption2).foregroundStyle(Color.konsensMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.financePanel()
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
                    .buttonStyle(.plain).foregroundStyle(.white).background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 10))
            }
        }.padding(20).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.10), Color(red: 0.025, green: 0.045, blue: 0.058)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.konsensViolet.opacity(0.17)))
    }
}

private extension View {
    func financePanel() -> some View {
        self.padding(15)
            .background(Color(red: 0.025, green: 0.047, blue: 0.060), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.konsensBlue.opacity(0.10)))
    }

    func financeFilter(active: Bool) -> some View {
        self.font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(active ? Color.konsensBackground : Color.konsensMuted)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(active ? Color.konsensBlue : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5))
    }
}
