import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showNetwork = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 15) {
                    Image("KonsensLogo")
                        .resizable().scaledToFit()
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: store.subscriptionTier == "premium" ? "KONSENS PREMIUM" : "KONSENS GRATUIT")
                        Text("@\(store.username)").font(.title.bold())
                        Text("Patrimoine \(store.wealth.total.formatted(.number.precision(.fractionLength(0)))) Koins").font(.caption).foregroundStyle(Color.konsensMuted)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ProfileStat(value: store.wealth.cash.formatted(.number.precision(.fractionLength(0))), label: "Koins disponibles")
                    ProfileStat(value: String(format: "%+.1f%%", store.wealth.performance), label: "Performance")
                    ProfileStat(value: store.wealth.investments.formatted(.number.precision(.fractionLength(0))), label: "Investi")
                    ProfileStat(value: store.wealth.bets.formatted(.number.precision(.fractionLength(0))), label: "En paris")
                }

                PremiumProfileCard()

                Button { showNetwork = true } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "network")
                            .font(.title3).foregroundStyle(Color.konsensBlue)
                            .frame(width: 44, height: 44)
                            .background(Color.konsensBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "KONSENS NETWORK")
                            Text("API · Publicité · Blockchain").font(.headline)
                            Text("Konsens Connect, revenus sponsorisés et suivi on-chain Premium.")
                                .font(.system(size: 9)).foregroundStyle(Color.konsensMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.konsensBlue)
                    }.panel()
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "SÉCURITÉ")
                    Label("Face ID protège l’accès à ton patrimoine", systemImage: "faceid").font(.subheadline.bold())
                    Text("L’authentification biométrique reste sur ton iPhone. Konsens ne reçoit aucune donnée biométrique.")
                        .font(.caption).foregroundStyle(Color.konsensMuted)
                }.panel()

                Button(role: .destructive) { Task { await store.signOut() } } label: {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.plain).foregroundStyle(Color.konsensNegative).background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .sheet(isPresented: $showNetwork) { NetworkView().environmentObject(store) }
    }
}

private struct PremiumProfileCard: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "KONSENS PREMIUM")
                    Text(store.subscriptionTier == "premium" ? "Premium actif" : "Moins de bruit. Plus de profondeur.")
                        .font(.title3.bold())
                }
                Spacer()
                Image(systemName: store.subscriptionTier == "premium" ? "checkmark.seal.fill" : "crown.fill")
                    .font(.title2).foregroundStyle(store.subscriptionTier == "premium" ? Color.konsensPositive : Color.konsensViolet)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                PremiumBenefit(icon: "rectangle.slash", title: "Sans pub", text: "Aucun format sponsorisé Konsens")
                PremiumBenefit(icon: "chart.xyaxis.line", title: "Finance", text: "Historiques et analyses enrichies")
                PremiumBenefit(icon: "link", title: "Blockchain", text: "Jusqu’à 10 wallets publics")
                PremiumBenefit(icon: "sparkles", title: "Analyse", text: "Outils avancés et tendances")
            }

            if store.subscriptionTier == "premium" {
                Label("Les emplacements publicitaires sont masqués pour ce compte.", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold()).foregroundStyle(Color.konsensPositive)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("4,99 € / mois au lancement").font(.headline)
                    Text("Bêta : active 14 jours gratuitement pour tester les droits Premium. Aucun paiement n’est débité pendant cette phase.")
                        .font(.caption).foregroundStyle(Color.konsensMuted)
                    Button { Task { await store.startPremiumTrial() } } label: {
                        Text("Activer 14 jours de Premium bêta")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(12)
                    }
                    .buttonStyle(.plain).foregroundStyle(.white).background(Color.konsensViolet, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Text("L’abonnement payant App Store sera raccordé avec StoreKit après création du produit dans App Store Connect. La bêta teste déjà les droits Premium réels côté compte.")
                .font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
        }
        .padding(20)
        .background(LinearGradient(colors: [Color.konsensViolet.opacity(0.13), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.konsensViolet.opacity(0.22)))
    }
}

private struct PremiumBenefit: View {
    let icon: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon).font(.caption).foregroundStyle(Color.konsensViolet)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(text).font(.system(size: 7)).foregroundStyle(Color.konsensMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(Color.konsensMuted)
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
