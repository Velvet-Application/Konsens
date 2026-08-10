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
                        .font(.subheadline).foregroundStyle(Color.konsensMuted)
                }
                WealthCard()
                RiskCard()
                if store.subscriptionTier == "free" {
                    SponsoredCard()
                }
                HStack(spacing: 10) {
                    Shortcut(title: "Jouer", detail: "Tester ton instinct", icon: "play.fill", tint: Color.konsensViolet) { store.selectedTab = .play }
                    Shortcut(title: "Investir", detail: "Bâtir ton portefeuille", icon: "chart.line.uptrend.xyaxis", tint: Color.konsensGreen) { store.selectedTab = .invest }
                }
                Shortcut(title: "Apprendre", detail: "Comprendre avant de risquer · \(store.lessons.count) cours", icon: "book.fill", tint: Color.konsensBlue) { store.selectedTab = .learn }
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
                Text("Koins").font(.caption).foregroundStyle(Color.konsensMuted)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06)).frame(height: 5)
                Capsule().fill(LinearGradient(colors: [Color.konsensGreen, Color.konsensBlue, Color.konsensViolet], startPoint: .leading, endPoint: .trailing)).frame(width: 165, height: 5)
            }
            HStack(spacing: 8) {
                WealthMini(title: "Disponible", value: store.wealth.cash)
                WealthMini(title: "Investi", value: store.wealth.investments)
                WealthMini(title: "Paris", value: store.wealth.bets)
            }
            Text("Départ : 1 000 Koins · aucune valeur monétaire")
                .font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
        }.panel()
    }
}

private struct WealthMini: View {
    let title: String; let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
            Text(value.formatted(.number.precision(.fractionLength(0)))).font(.subheadline.monospacedDigit().bold())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RiskCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled").foregroundStyle(Color.konsensGold).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Gagner vite signifie aussi pouvoir perdre vite.").font(.subheadline.bold())
                Text("Konsens rend le risque visible avec des Koins fictifs, jamais achetables ni convertibles en argent.").font(.caption).foregroundStyle(Color.konsensMuted)
            }
        }.padding(16).background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensGold.opacity(0.15)))
    }
}

private struct SponsoredCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var ad: SponsoredAd?
    @State private var sessionID = UUID().uuidString
    @State private var impressionTracked = false

    var body: some View {
        Group {
            if let ad {
                Button {
                    Task { await track(ad, type: "click") }
                    if let url = URL(string: ad.destinationURL) { openURL(url) }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title3).foregroundStyle(Color.konsensGold)
                            .frame(width: 44, height: 44)
                            .background(Color.konsensGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Text(ad.eyebrow.uppercased()).font(.system(size: 7, weight: .bold)).tracking(1)
                                Text("· \(ad.sponsorName)").font(.system(size: 7, weight: .bold))
                            }.foregroundStyle(Color.konsensGold)
                            Text(ad.headline).font(.subheadline.bold()).multilineTextAlignment(.leading)
                            if let body = ad.body {
                                Text(body).font(.system(size: 9)).foregroundStyle(Color.konsensMuted).lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(Color.konsensGold)
                    }
                    .padding(16)
                    .background(LinearGradient(colors: [Color.konsensGold.opacity(0.08), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.konsensGold.opacity(0.14)))
                }.buttonStyle(.plain)
            }
        }
        .task { await load() }
    }

    private func load() async {
        struct Params: Encodable { let p_placement: String; let p_session_id: String }
        struct Row: Decodable {
            let campaign_id: UUID
            let creative_id: UUID
            let sponsor_name: String
            let eyebrow: String
            let headline: String
            let body: String?
            let cta_label: String
            let destination_url: String
            let placement: String
        }
        let params = Params(p_placement: "feed_native", p_session_id: sessionID)
        if let rows: [Row] = try? await store.supabase.rpc("get_active_ad", params: params).execute().value,
           let row = rows.first {
            let loaded = SponsoredAd(campaignID: row.campaign_id, id: row.creative_id, sponsorName: row.sponsor_name, eyebrow: row.eyebrow, headline: row.headline, body: row.body, ctaLabel: row.cta_label, destinationURL: row.destination_url, placement: row.placement)
            ad = loaded
            if !impressionTracked {
                impressionTracked = true
                await track(loaded, type: "impression")
            }
        }
    }

    private func track(_ ad: SponsoredAd, type: String) async {
        struct Params: Encodable {
            let p_campaign_id: UUID
            let p_creative_id: UUID
            let p_event_type: String
            let p_placement: String
            let p_session_id: String
        }
        let params = Params(p_campaign_id: ad.campaignID, p_creative_id: ad.id, p_event_type: type, p_placement: ad.placement, p_session_id: sessionID)
        _ = try? await store.supabase.rpc("track_ad_event", params: params).execute()
    }
}

private struct Shortcut: View {
    let title: String; let detail: String; let icon: String; let tint: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.headline).foregroundStyle(tint).frame(width: 40, height: 40).background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(detail).font(.system(size: 9)).foregroundStyle(Color.konsensMuted) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(tint)
            }.panel()
        }.buttonStyle(.plain)
    }
}

private struct PremiumCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet)
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "KONSENS PREMIUM")
                Text(store.subscriptionTier == "premium" ? "Premium actif" : "4,99 € / mois").font(.headline)
                Text("Sans pub · prédictif · détails des portefeuilles · flux financiers API et suivi blockchain").font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
        }.padding(18).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensViolet.opacity(0.2)))
    }
}
