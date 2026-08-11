import Foundation
import SwiftUI
import WatchConnectivity

struct WatchMarket: Codable, Hashable { let question:String; let category:String; let probability:Int; let volume:Int; let movement:Double }
struct WatchAsset: Codable, Hashable { let symbol:String; let name:String; let price:Double; let change:Double; let currency:String }

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var wealth = 1000
    @Published var performance = 0.0
    @Published var score = 50
    @Published var progress = 0
    @Published var next = "Comprendre"
    @Published var streak = 0
    @Published var markets:[WatchMarket] = []
    @Published var assets:[WatchAsset] = []
    @Published var updated:Date?

    override init(){super.init();if WCSession.isSupported(){WCSession.default.delegate=self;WCSession.default.activate()}}
    func session(_ session:WCSession,activationDidCompleteWith activationState:WCSessionActivationState,error:Error?){}
    func session(_ session:WCSession,didReceiveApplicationContext applicationContext:[String:Any]){apply(applicationContext)}
    private func apply(_ context:[String:Any]){DispatchQueue.main.async{self.wealth=context["wealth"] as? Int ?? self.wealth;self.performance=context["performance"] as? Double ?? self.performance;self.score=context["journey_score"] as? Int ?? self.score;self.progress=context["journey_progress"] as? Int ?? self.progress;self.next=context["journey_next"] as? String ?? self.next;self.streak=context["journey_streak"] as? Int ?? self.streak;if let data=context["markets"] as? Data{self.markets=(try? JSONDecoder().decode([WatchMarket].self,from:data)) ?? self.markets};if let data=context["assets"] as? Data{self.assets=(try? JSONDecoder().decode([WatchAsset].self,from:data)) ?? self.assets};if let stamp=context["updated"] as? Double,stamp>0{self.updated=Date(timeIntervalSince1970:stamp)}}}
}

@main struct KonsensWatchApp:App{@StateObject private var store=WatchStore();var body:some Scene{WindowGroup{WatchHome().environmentObject(store)}}}

struct WatchHome:View{
    @EnvironmentObject private var store:WatchStore
    var body:some View{ZStack{Color(red:0.025,green:0.045,blue:0.065).ignoresSafeArea();ScrollView{VStack(alignment:.leading,spacing:10){
        HStack{Image("KonsensLogo").resizable().scaledToFit().frame(width:30,height:30).clipShape(RoundedRectangle(cornerRadius:8));VStack(alignment:.leading,spacing:0){Text("KONSENS").font(.caption2.bold());Text("DAILY").font(.system(size:7,weight:.black)).foregroundStyle(.mint)};Spacer()}
        VStack(alignment:.leading,spacing:6){HStack{VStack(alignment:.leading,spacing:0){Text("KONSENS SCORE").font(.system(size:7,weight:.black)).foregroundStyle(.mint);Text("\(store.score)/100").font(.title2.monospacedDigit().bold())};Spacer();ZStack{Circle().stroke(Color.white.opacity(0.09),lineWidth:5);Circle().trim(from:0,to:CGFloat(store.progress)/4).stroke(Color.mint,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90));Text("\(store.progress)/4").font(.system(size:9,weight:.black))}.frame(width:48,height:48)};Text(store.progress>=4 ? "Entraînement terminé" : "Prochaine étape · \(store.next)").font(.caption.bold());Text("\(store.streak) j de régularité").font(.system(size:7)).foregroundStyle(.secondary)}.padding(10).background(LinearGradient(colors:[Color.mint.opacity(0.09),Color.white.opacity(0.035)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:13))
        if let market=store.markets.first{VStack(alignment:.leading,spacing:4){HStack{Text("PRÉDIRE").font(.system(size:7,weight:.black)).foregroundStyle(.purple);Spacer();Text("\(market.probability)% OUI").font(.caption.bold()).foregroundStyle(.mint)};Text(market.question).font(.system(size:10,weight:.semibold)).lineLimit(3);Text("Ouvre l’iPhone pour enregistrer ta conviction.").font(.system(size:7)).foregroundStyle(.secondary)}.padding(9).background(Color.purple.opacity(0.08),in:RoundedRectangle(cornerRadius:12))}
        if let asset=store.assets.first{HStack{VStack(alignment:.leading){Text("DÉCIDER").font(.system(size:7,weight:.black)).foregroundStyle(.blue);Text(asset.symbol).font(.caption.bold());Text(asset.price.formatted(.number.precision(.fractionLength(2)))).font(.headline.monospacedDigit())};Spacer();Text(String(format:"%+.1f%%",asset.change)).font(.caption.bold()).foregroundStyle(asset.change>=0 ? .green:.red)}.padding(9).background(Color.blue.opacity(0.07),in:RoundedRectangle(cornerRadius:12))}
        HStack{Text("Patrimoine fictif").font(.system(size:7)).foregroundStyle(.secondary);Spacer();Text("\(store.wealth) K").font(.caption.monospacedDigit().bold())}.padding(9).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:11))
        Text(store.updated.map{"Mis à jour \($0.formatted(date:.omitted,time:.shortened))"} ?? "Ouvre Konsens sur iPhone pour synchroniser").font(.system(size:7)).foregroundStyle(.secondary)
    }.padding(.horizontal,4)}}}
}
