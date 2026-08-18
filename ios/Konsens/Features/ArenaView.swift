import SwiftUI

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DailyJourneyHero(username: store.username, wealth: store.wealth)
                ThreeWorldJourney()

                HStack(spacing: 10) {
                    JourneyInsight(
                        icon: "arrow.up.right",
                        title: "Gagner",
                        text: "Une bonne décision peut faire progresser tes Koins.",
                        tint: Color.konsensPositive
                    )
                    JourneyInsight(
                        icon: "arrow.down.right",
                        title: "Perdre",
                        text: "Une mauvaise décision peut réduire ton portefeuille.",
                        tint: Color.konsensNegative
                    )
                }

                LearningLoopCard()

                if store.subscriptionTier == "free" {
                    SponsoredCard()
                }

                PremiumCard()
            }
            .padding(.horizontal, 18)
            .padding(.top, 106)
            .padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
    }
}

private struct DailyJourneyHero: View {
    let username: String
    let wealth: WealthSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Capsule().fill(Color.konsensGreen).frame(width: 40, height: 3)
                Text("TON KONSENS DU JOUR")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color.konsensGreen)
            }

            Text("Bonjour \(username).")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))

            Text("Entraîne ta capacité à prendre de meilleures décisions avec l’argent.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Aujourd’hui, ne cherche pas seulement à gagner : apprends à comprendre pourquoi une décision peut fonctionner… ou te faire perdre.")
                .font(.subheadline)
                .foregroundStyle(Color.konsensMuted)
                .lineSpacing(3)

            HStack(spacing: 8) {
                heroMetric("\(Int(wealth.total.rounded())) K", "PATRIMOINE", wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                heroMetric(String(format: "%+.1f%%", wealth.performance), "DEPUIS LE DÉPART", wealth.performance >= 0 ? Color.konsensPositive : Color.konsensNegative)
                heroMetric("0 €", "ARGENT RÉEL", Color.konsensGreen)
            }
        }
        .padding(19)
        .background(
            LinearGradient(
                colors: [Color.konsensGreen.opacity(0.10), Color.konsensViolet.opacity(0.055), Color.konsensPanel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26)
        )
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.konsensGreen.opacity(0.15)))
    }

    private func heroMetric(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.monospacedDigit().bold()).foregroundStyle(tint)
            Text(label).font(.system(size: 5, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ThreeWorldJourney: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TON PARCOURS")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.konsensGreen)
                    Text("3 univers · 1 compétence").font(.title3.bold())
                }
                Spacer()
                Text("COMPRENDRE → DÉCIDER")
                    .font(.system(size: 6, weight: .black, design: .rounded))
                    .foregroundStyle(Color.konsensMuted)
            }

            WorldJourneyCard(
                number: "01",
                title: "Jouer",
                subtitle: "Teste ton intuition contre le consensus.",
                lesson: "Apprends à mesurer ta confiance et à accepter de te tromper.",
                icon: "bolt.fill",
                tint: Color.konsensViolet
            ) { store.selectedTab = .play }

            pathConnector

            WorldJourneyCard(
                number: "02",
                title: "Investir",
                subtitle: "Observe les marchés et la blockchain.",
                lesson: "Compare le potentiel de gain au risque de perte avant d’engager tes Koins.",
                icon: "chart.line.uptrend.xyaxis",
                tint: Color.konsensBlue
            ) { store.selectedTab = .invest }

            pathConnector

            WorldJourneyCard(
                number: "03",
                title: "Apprendre",
                subtitle: "Transforme tes erreurs en connaissances.",
                lesson: "Progresse par niveaux, exemples, vidéos et quiz.",
                icon: "graduationcap.fill",
                tint: Color.konsensGreen
            ) { store.selectedTab = .learn }
        }
    }

    private var pathConnector: some View {
        HStack {
            Rectangle().fill(Color.clear).frame(width: 28)
            Capsule().fill(Color.konsensGreen.opacity(0.55)).frame(width: 3, height: 22)
            Spacer()
        }
    }
}

private struct WorldJourneyCard: View {
    let number: String
    let title: String
    let subtitle: String
    let lesson: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(tint.opacity(0.12))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                    VStack(spacing: 2) {
                        Image(systemName: icon).font(.title3.bold()).foregroundStyle(tint)
                        Text(number).font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted)
                    }
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.title3.bold())
                    Text(subtitle).font(.caption.bold()).foregroundStyle(tint)
                    Text(lesson).font(.system(size: 9)).foregroundStyle(Color.konsensMuted).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.title3).foregroundStyle(tint)
            }
            .padding(14)
            .background(tint.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyInsight: View {
    let icon: String
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.headline.bold())
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            Text(title).font(.headline)
            Text(text).font(.system(size: 9)).foregroundStyle(Color.konsensMuted).lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.035), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(tint.opacity(0.10)))
    }
}

private struct LearningLoopCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Capsule().fill(Color.konsensGreen).frame(width: 34, height: 3)
                Text("LA LIGNE VERTE")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color.konsensGreen)
            }
            Text("Comprendre → prédire → décider → observer → apprendre.")
                .font(.headline)
            Text("Tes Koins rendent chaque choix concret sans mettre d’argent réel en jeu. La performance compte, mais la maîtrise du risque et la compréhension comptent davantage.")
                .font(.caption)
                .foregroundStyle(Color.konsensMuted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.konsensGreen.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensGreen.opacity(0.12)))
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
                    .background(
                        LinearGradient(
                            colors: [Color.konsensGold.opacity(0.08), Color.konsensPanel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 19)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.konsensGold.opacity(0.14)))
                }
                .buttonStyle(.plain)
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
            let loaded = SponsoredAd(
                campaignID: row.campaign_id,
                id: row.creative_id,
                sponsorName: row.sponsor_name,
                eyebrow: row.eyebrow,
                headline: row.headline,
                body: row.body,
                ctaLabel: row.cta_label,
                destinationURL: row.destination_url,
                placement: row.placement
            )
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
        _ = try? await store.supabase.rpc(
            "track_ad_event",
            params: Params(
                p_campaign_id: ad.campaignID,
                p_creative_id: ad.id,
                p_event_type: type,
                p_placement: ad.placement,
                p_session_id: sessionID
            )
        ).execute()
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
                Text("Sans pub · analyses avancées · alertes · transparence blockchain enrichie")
                    .font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensViolet.opacity(0.2)))
    }
}