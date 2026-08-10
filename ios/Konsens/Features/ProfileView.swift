import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 15) {
                    Text(String(store.username.prefix(2)).uppercased())
                        .font(.headline.bold()).frame(width: 62, height: 62)
                        .background(LinearGradient(colors: [.konsensGreen.opacity(0.2), .konsensViolet.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: store.subscriptionTier == "premium" ? "KONSENS PREMIUM" : "KONSENS GRATUIT")
                        Text("@\(store.username)").font(.title.bold())
                        Text("Patrimoine \(store.wealth.total.formatted(.number.precision(.fractionLength(0)))) Koins").font(.caption).foregroundStyle(.konsensMuted)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ProfileStat(value: store.wealth.cash.formatted(.number.precision(.fractionLength(0))), label: "Koins disponibles")
                    ProfileStat(value: String(format: "%+.1f%%", store.wealth.performance), label: "Performance")
                    ProfileStat(value: store.wealth.investments.formatted(.number.precision(.fractionLength(0))), label: "Investi")
                    ProfileStat(value: store.wealth.bets.formatted(.number.precision(.fractionLength(0))), label: "En paris")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "SÉCURITÉ")
                    Label("Face ID protège l’accès à ton patrimoine", systemImage: "faceid").font(.subheadline.bold())
                    Text("L’authentification biométrique reste sur ton iPhone. Konsens ne reçoit aucune donnée biométrique.")
                        .font(.caption).foregroundStyle(.konsensMuted)
                }.panel()
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "ABONNEMENT")
                    Text(store.subscriptionTier == "premium" ? "Premium actif" : "Gratuit + publicité").font(.headline)
                    Text("Premium à 4,99 € / mois : sans pub, analyses enrichies, détails des portefeuilles et futurs flux financiers API.")
                        .font(.caption).foregroundStyle(.konsensMuted)
                }.panel()
                Button(role: .destructive) { Task { await store.signOut() } } label: {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.plain).foregroundStyle(.konsensNegative).background(Color.konsensNegative.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.konsensMuted)
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
