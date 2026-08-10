import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            Color.konsensBackground.ignoresSafeArea()
            TabView(selection: $store.selectedTab) {
                ArenaView().tag(AppTab.arena).tabItem { Label("Arène", systemImage: "waveform.path.ecg") }
                MarketsView().tag(AppTab.markets).tabItem { Label("Marchés", systemImage: "chart.line.uptrend.xyaxis") }
                LeagueView().tag(AppTab.league).tabItem { Label("Ligue", systemImage: "trophy") }
                ProfileView().tag(AppTab.profile).tabItem { Label("Profil", systemImage: "person.crop.circle") }
            }
            .tint(.konsensGreen)
            if let toast = store.toast { VStack { Spacer(); Text("✓  \(toast)").font(.footnote.bold()).foregroundStyle(Color.konsensBackground).padding(.horizontal, 17).padding(.vertical, 11).background(.white, in: Capsule()).padding(.bottom, 72).transition(.move(edge: .bottom).combined(with: .opacity)) } }
        }
        .animation(.snappy, value: store.toast)
        .sheet(item: $store.activeMarket) { TradeSheet(market: $0).presentationDetents([.medium]).presentationDragIndicator(.visible).presentationCornerRadius(28) }
    }
}
