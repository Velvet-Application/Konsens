import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store:AppStore
    var body:some View{ZStack{Color.konsensBackground.ignoresSafeArea();if store.isLoading{ProgressView().tint(.konsensGreen)}else if !store.isAuthenticated{AuthView()}else if !store.onboardingComplete{NativeOnboardingView()}else{tabs};if let toast=store.toast{VStack{Spacer();Text(toast).font(.footnote.bold()).padding(12).background(.white,in:Capsule()).foregroundStyle(.black).padding(.bottom,72)}}}}
    private var tabs:some View{TabView(selection:$store.selectedTab){ArenaView().tag(AppTab.arena).tabItem{Label("Accueil",systemImage:"house")};MarketsView().tag(AppTab.markets).tabItem{Label("Challenges",systemImage:"bolt")};LeagueView().tag(AppTab.league).tabItem{Label("Créer",systemImage:"plus.circle")};ProfileView().tag(AppTab.profile).tabItem{Label("Profil",systemImage:"person.crop.circle")}}.tint(.konsensGreen)}
}
