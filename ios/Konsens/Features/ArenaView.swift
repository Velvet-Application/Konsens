import SwiftUI

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) { Eyebrow(text: "DIMANCHE 10 AOÛT"); Text("Bonjour Cyril.").font(.largeTitle.bold()); Text("Une décision peut te faire passer 3e.").foregroundStyle(.konsensMuted) }
                    PortfolioCard()
                    DailyChallenge()
                    WeeklyMission()
                    VStack(alignment: .leading, spacing: 13) {
                        HStack { VStack(alignment: .leading) { Eyebrow(text: "POSITIONS"); Text("Ton portefeuille").font(.title3.bold()) }; Spacer(); Button("Tout gérer →") { store.selectedTab = .markets }.foregroundStyle(.konsensGreen) }
                        ForEach(store.positions) { position in PositionRow(position: position) }
                    }.panel()
                }.padding(18).padding(.bottom, 20)
            }
            .background(Color.konsensBackground)
            .toolbar { ToolbarItem(placement: .topBarLeading) { HStack(spacing: 8) { Text("K").font(.headline.black()).foregroundStyle(Color.konsensBackground).frame(width: 29, height: 29).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 8)); Text("KONSENS").font(.caption.bold()).tracking(1.8) } } }
        }
    }
}

private struct PortfolioCard: View {
    @EnvironmentObject private var store: AppStore
    var body: some View { VStack(alignment: .leading, spacing: 17) {
        HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Text("VALEUR DU PORTEFEUILLE").font(.caption2.bold()).foregroundStyle(.konsensMuted); Text("\(store.credits.formatted(.number)) cr.").font(.system(size: 37, weight: .bold, design: .rounded)); Text("↗ +6,8 % cette saison").font(.caption).foregroundStyle(.konsensGreen) }; Spacer(); VStack(alignment: .trailing) { Text("CLASSEMENT").font(.caption2.bold()).foregroundStyle(.konsensMuted); Text("#4").font(.title.bold()); Text("sur 24").font(.caption2).foregroundStyle(.konsensMuted) } }
        GeometryReader { proxy in HStack(spacing: 3) { Color(hex: 0x315249).frame(width: proxy.size.width*0.25); Color(hex: 0x638CFF).frame(width: proxy.size.width*0.32); Color(hex: 0x9B7AFF).frame(width: proxy.size.width*0.16); Color(hex: 0xE7B55D).frame(width: proxy.size.width*0.12); Color.konsensGreen }.clipShape(Capsule()) }.frame(height: 8)
        Text("Cash 25 %   ·   Actions 34 %   ·   ETF 16 %   ·   Prédictions 12 %").font(.system(size: 9)).foregroundStyle(.konsensMuted)
    }.panel() }
}

private struct DailyChallenge: View {
    @EnvironmentObject private var store: AppStore
    var body: some View { VStack(alignment: .leading, spacing: 14) { HStack { Image(systemName:"bolt.fill").foregroundStyle(.konsensGreen); VStack(alignment:.leading){Eyebrow(text:"DÉFI DU JOUR");Text("Série de \(store.streak) jours").font(.caption.bold())};Spacer();Text("+40 XP").font(.caption.monospaced()).foregroundStyle(.konsensGreen) }; Text("L’inflation française repassera-t-elle sous 2 % avant octobre ?").font(.headline); Text("Clôture aujourd’hui à 20:00").font(.caption).foregroundStyle(.konsensMuted)
        if let answer = store.dailyAnswer { Label("Position \(answer ? "OUI" : "NON") enregistrée", systemImage:"checkmark.circle.fill").font(.subheadline.bold()).foregroundStyle(.konsensGreen).padding(13).frame(maxWidth:.infinity,alignment:.leading).background(Color.konsensGreen.opacity(.1),in:RoundedRectangle(cornerRadius:12)) }
        else { HStack { ChoiceButton(title:"OUI",color:.konsensGreen){store.answerDaily(true)};ChoiceButton(title:"NON",color:.red){store.answerDaily(false)} } }
    }.panel() }
}

struct ChoiceButton: View { let title:String;let color:Color;let action:()->Void;var body:some View{Button(action:action){Text(title).font(.subheadline.bold()).frame(maxWidth:.infinity).padding(13).background(color.opacity(.1),in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(.25)))}.foregroundStyle(color)} }
private struct WeeklyMission: View { var body:some View{VStack(alignment:.leading,spacing:12){HStack{VStack(alignment:.leading){Eyebrow(text:"MISSION HEBDO");Text("L’analyste diversifié").font(.headline)};Spacer();Text("2/3").font(.caption.monospaced()).foregroundStyle(.konsensGreen)};Text("Prends position sur trois catégories différentes.").font(.caption).foregroundStyle(.konsensMuted);ProgressView(value:0.67).tint(.konsensGreen);Text("120 XP · Badge Stratège").font(.caption.bold())}.panel()} }
private struct PositionRow:View{let position:Position;var body:some View{HStack{Text(position.symbol).font(.caption2.black()).foregroundStyle(Color.konsensBackground).frame(width:39,height:39).background(Color(hex:position.colorHex),in:RoundedRectangle(cornerRadius:10));VStack(alignment:.leading){Text(position.name).font(.subheadline.bold());Text(position.symbol).font(.caption2).foregroundStyle(.konsensMuted)};Spacer();VStack(alignment:.trailing){Text("\(position.value.formatted()) cr.").font(.subheadline.bold());Text("+\(position.performance,specifier:"%.1f") %").font(.caption2).foregroundStyle(.konsensGreen)}}} }
