import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var role = "member"
    @State private var monetization = MonetizationSnapshot()
    @State private var wallets: [PublicWallet] = []
    @State private var followed: Set<UUID> = []
    @State private var events: [WalletEvent] = []
    @State private var comparisons: [RealityComparison] = []
    @State private var loading = true

    private var premiumUnlocked: Bool {
        store.subscriptionTier == "premium" || store.subscriptionTier == "plus" || role == "admin"
    }

    var body: some View {
        ZStack {
            Color.konsensBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack {
                        KonsensMark()
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.headline).frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }.buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "KONSENS NETWORK")
                        Text("API, publicité & blockchain.").font(.system(size: 31, weight: .bold, design: .rounded))
                        Text("La couche qui transforme les décisions Konsens en signaux monétisables et en données vérifiables.")
                            .font(.subheadline).foregroundStyle(Color.konsensMuted)
                    }

                    if loading {
                        ProgressView("Connexion à Konsens Network…").tint(Color.konsensGreen).panel()
                    } else {
                        revenueSection
                        blockchainSection
                        realitySection
                    }
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .refreshable { await load() }
    }

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "KONSENS REVENUE")
                    Text("Ads + Connect + Signals API").font(.title3.bold())
                }
                Spacer()
                Image(systemName: "network").font(.title2).foregroundStyle(Color.konsensBlue)
            }

            Text("La version Free accueille des formats sponsorisés contextuels. Konsens Connect permet aux partenaires d’intégrer les signaux agrégés via SDK/API.")
                .font(.caption).foregroundStyle(Color.konsensMuted)

            if role == "admin" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    NetworkMetric(value: "\(monetization.advertisers)", label: "Annonceurs")
                    NetworkMetric(value: "\(monetization.activeCampaigns)", label: "Campagnes actives")
                    NetworkMetric(value: "\(monetization.impressions)", label: "Impressions")
                    NetworkMetric(value: String(format: "%.2f%%", monetization.ctr), label: "CTR")
                }
                HStack {
                    Label("\(monetization.sdkClients) clients SDK actifs", systemImage: "curlybraces.square")
                    Spacer()
                    Text("ADMIN").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.konsensBlue)
                }.font(.caption.bold())
            } else {
                Label("Données commercialisables uniquement sous forme agrégée", systemImage: "checkmark.shield.fill")
                    .font(.caption.bold()).foregroundStyle(Color.konsensPositive)
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [Color.konsensBlue.opacity(0.13), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensBlue.opacity(0.18)))
    }

    private var blockchainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "KONSENS CHAIN")
                    Text("Portefeuilles publics vérifiables").font(.title3.bold())
                }
                Spacer()
                Text("\(followed.count)/10").font(.headline.monospacedDigit()).foregroundStyle(Color.konsensViolet)
            }

            Text("Suis jusqu’à 10 portefeuilles publics et observe transferts, swaps et mouvements DeFi. Les Koins restent fictifs : aucun Koin n’est une cryptomonnaie.")
                .font(.caption).foregroundStyle(Color.konsensMuted)

            if !premiumUnlocked {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill").foregroundStyle(Color.konsensViolet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Inclus dans Premium · 4,99 €/mois").font(.subheadline.bold())
                        Text("Aperçu visible, suivi et alertes déverrouillés avec Premium.").font(.caption).foregroundStyle(Color.konsensMuted)
                    }
                }.padding(14).background(Color.konsensViolet.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }

            if wallets.isEmpty {
                NetworkEmpty(icon: "link.badge.plus", title: "Aucun portefeuille indexé", text: "Le connecteur blockchain est prêt ; les premiers portefeuilles apparaîtront après ingestion du fournisseur on-chain.")
            } else {
                ForEach(wallets.prefix(6)) { wallet in
                    walletRow(wallet)
                }
            }

            if !events.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                Eyebrow(text: "DERNIERS MOUVEMENTS")
                ForEach(events.prefix(6)) { event in
                    eventRow(event)
                }
            }
        }.panel()
    }

    private func walletRow(_ wallet: PublicWallet) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "wallet.bifold.fill")
                .foregroundStyle(Color.konsensViolet)
                .frame(width: 38, height: 38)
                .background(Color.konsensViolet.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(wallet.displayName).font(.subheadline.bold())
                Text("\(wallet.chain.uppercased()) · \(wallet.shortAddress) · confiance \(wallet.confidenceScore)%")
                    .font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                if let value = wallet.observableValueEUR {
                    Text(value.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                        .font(.caption.monospacedDigit().bold())
                }
            }
            Spacer()
            Button {
                Task { await toggle(wallet) }
            } label: {
                Image(systemName: followed.contains(wallet.id) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3).foregroundStyle(followed.contains(wallet.id) ? Color.konsensPositive : Color.konsensViolet)
            }
            .buttonStyle(.plain)
            .disabled(!premiumUnlocked)
        }
        .padding(12).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
    }

    private func eventRow(_ event: WalletEvent) -> some View {
        HStack(spacing: 10) {
            Image(systemName: event.direction == "in" ? "arrow.down.left" : "arrow.up.right")
                .foregroundStyle(event.direction == "in" ? Color.konsensPositive : Color.konsensGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.eventLabel) · \(event.assetSymbol ?? "ACTIF")").font(.caption.bold())
                Text(event.blockTime.map(shortDate) ?? "Horodatage indisponible").font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
            if let amount = event.estimatedValueEUR {
                Text(amount.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit().bold())
            }
            if let raw = event.explorerURL, let url = URL(string: raw) {
                Button { openURL(url) } label: { Image(systemName: "arrow.up.forward.square") }
                    .buttonStyle(.plain).foregroundStyle(Color.konsensBlue)
            }
        }
        .padding(.vertical, 4)
    }

    private var realitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "SIMULATION ↔ RÉALITÉ")
            Text("Mesurer ce que le marché réel aurait changé.").font(.title3.bold())
            Text("Konsens compare une décision simulée à sa valeur de marché, puis isole frais réseau et slippage pour éviter une illusion de performance.")
                .font(.caption).foregroundStyle(Color.konsensMuted)

            if let comparison = comparisons.first {
                HStack(spacing: 8) {
                    NetworkMetric(value: comparison.simulatedValueEUR.formatted(.currency(code: "EUR").precision(.fractionLength(0))), label: "Simulation")
                    NetworkMetric(value: comparison.realMarketValueEUR.formatted(.currency(code: "EUR").precision(.fractionLength(0))), label: "Marché")
                }
                HStack {
                    Text("Frais + slippage")
                    Spacer()
                    Text((comparison.networkFeesEUR + comparison.slippageEUR).formatted(.currency(code: "EUR").precision(.fractionLength(2))))
                }.font(.caption).foregroundStyle(Color.konsensMuted)
            } else {
                NetworkEmpty(icon: "arrow.left.arrow.right", title: "Comparaison prête", text: "Aucune comparaison enregistrée pour ce compte. Le flux marché sera branché au fournisseur API de production.")
            }
        }.panel()
    }

    private func load() async {
        loading = true
        guard let userID = store.supabase.auth.currentUser?.id else { loading = false; return }

        struct ProfileRole: Decodable { let role: String }
        if let profile: ProfileRole = try? await store.supabase.from("profiles").select("role").eq("id", value: userID).single().execute().value {
            role = profile.role
        }

        await loadBlockchain(userID: userID)
        if role == "admin" { await loadRevenue() }
        loading = false
    }

    private func loadRevenue() async {
        struct UUIDRow: Decodable { let id: UUID }
        struct CampaignRow: Decodable { let id: UUID; let status: String }
        struct EventRow: Decodable { let id: Int64; let event_type: String }
        struct ClientRow: Decodable { let id: UUID; let status: String }

        let advertisers: [UUIDRow] = (try? await store.supabase.from("advertisers").select("id").execute().value) ?? []
        let campaigns: [CampaignRow] = (try? await store.supabase.from("ad_campaigns").select("id,status").execute().value) ?? []
        let adEvents: [EventRow] = (try? await store.supabase.from("ad_events").select("id,event_type").limit(5000).execute().value) ?? []
        let clients: [ClientRow] = (try? await store.supabase.from("sdk_clients").select("id,status").execute().value) ?? []

        monetization = MonetizationSnapshot(
            advertisers: advertisers.count,
            activeCampaigns: campaigns.filter { $0.status == "active" }.count,
            impressions: adEvents.filter { $0.event_type == "impression" }.count,
            clicks: adEvents.filter { $0.event_type == "click" }.count,
            sdkClients: clients.filter { $0.status == "active" }.count
        )
    }

    private func loadBlockchain(userID: UUID) async {
        struct WalletRow: Decodable {
            let id: UUID
            let chain: String
            let address: String
            let display_name: String
            let confidence_score: Int
            let observable_value_eur: Double?
        }
        struct FollowRow: Decodable { let wallet_id: UUID }
        struct EventRow: Decodable {
            let id: UUID
            let wallet_id: UUID
            let event_type: String
            let direction: String
            let asset_symbol: String?
            let asset_amount: Double?
            let estimated_value_eur: Double?
            let block_time: String?
            let explorer_url: String?
        }
        struct ComparisonRow: Decodable {
            let id: UUID
            let simulated_value_eur: Double
            let real_market_value_eur: Double
            let network_fees_eur: Double
            let slippage_eur: Double
            let compared_at: String
        }

        let walletRows: [WalletRow] = (try? await store.supabase.from("public_wallets")
            .select("id,chain,address,display_name,confidence_score,observable_value_eur")
            .eq("is_active", value: true)
            .order("observable_value_eur", ascending: false)
            .limit(20).execute().value) ?? []
        wallets = walletRows.map { PublicWallet(id: $0.id, chain: $0.chain, address: $0.address, displayName: $0.display_name, confidenceScore: $0.confidence_score, observableValueEUR: $0.observable_value_eur) }

        let followRows: [FollowRow] = (try? await store.supabase.from("wallet_follows").select("wallet_id").eq("user_id", value: userID).execute().value) ?? []
        followed = Set(followRows.map(\.wallet_id))

        let eventRows: [EventRow] = (try? await store.supabase.from("wallet_events")
            .select("id,wallet_id,event_type,direction,asset_symbol,asset_amount,estimated_value_eur,block_time,explorer_url")
            .order("block_time", ascending: false).limit(30).execute().value) ?? []
        events = eventRows.map { WalletEvent(id: $0.id, walletID: $0.wallet_id, eventType: $0.event_type, direction: $0.direction, assetSymbol: $0.asset_symbol, assetAmount: $0.asset_amount, estimatedValueEUR: $0.estimated_value_eur, blockTime: $0.block_time, explorerURL: $0.explorer_url) }

        let comparisonRows: [ComparisonRow] = (try? await store.supabase.from("reality_comparisons")
            .select("id,simulated_value_eur,real_market_value_eur,network_fees_eur,slippage_eur,compared_at")
            .eq("user_id", value: userID).order("compared_at", ascending: false).limit(10).execute().value) ?? []
        comparisons = comparisonRows.map { RealityComparison(id: $0.id, simulatedValueEUR: $0.simulated_value_eur, realMarketValueEUR: $0.real_market_value_eur, networkFeesEUR: $0.network_fees_eur, slippageEUR: $0.slippage_eur, comparedAt: $0.compared_at) }
    }

    private func toggle(_ wallet: PublicWallet) async {
        guard premiumUnlocked, let userID = store.supabase.auth.currentUser?.id else { return }
        do {
            if followed.contains(wallet.id) {
                try await store.supabase.from("wallet_follows").delete().eq("user_id", value: userID).eq("wallet_id", value: wallet.id).execute()
                followed.remove(wallet.id)
            } else {
                guard followed.count < 10 else { store.showToast("Maximum 10 portefeuilles suivis"); return }
                struct FollowInsert: Encodable {
                    let user_id: UUID
                    let wallet_id: UUID
                    let minimum_alert_eur: Double
                    let notifications_enabled: Bool
                }
                try await store.supabase.from("wallet_follows").insert(FollowInsert(user_id: userID, wallet_id: wallet.id, minimum_alert_eur: 10_000, notifications_enabled: true)).execute()
                followed.insert(wallet.id)
            }
            await loadBlockchain(userID: userID)
        } catch {
            store.showToast("Impossible de modifier le suivi blockchain")
        }
    }

    private func shortDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct NetworkMetric: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(11).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct NetworkEmpty: View {
    let icon: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).foregroundStyle(Color.konsensMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.bold())
                Text(text).font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
            }
        }.padding(13).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
    }
}
