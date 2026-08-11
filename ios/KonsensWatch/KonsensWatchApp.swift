import SwiftUI
import WatchConnectivity

struct WatchMarket: Codable, Hashable { let question:String; let category:String; let probability:Int; let volume:Int; let movement:Double }
struct WatchAsset: Codable, Hashable { let symbol:String; let name:String; let price:Double; let change:Double; let currency:String }

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var wealth = 1000
    @Published var performance = 0.0
    @Published var markets: [WatchMarket] = []
    @Published var assets: [WatchAsset] = []
    @Published var updated: Date?

    override init() {
        super.init()
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) { apply(applicationContext) }

    private func apply(_ context: [String:Any]) {
        DispatchQueue.main.async {
            self.wealth = context["wealth"] as? Int ?? self.wealth
            self.performance = context["performance"] as? Double ?? self.performance
            if let data = context["markets"] as? Data { self.markets = (try? JSONDecoder().decode([WatchMarket].self, from: data)) ?? self.markets }
            if let data = context["assets"] as? Data { self.assets = (try? JSONDecoder().decode([WatchAsset].self, from: data)) ?? self.assets }
            if let stamp = context["updated"] as? Double, stamp > 0 { self.updated = Date(timeIntervalSince1970: stamp) }
        }
    }
}

@main
struct KonsensWatchApp: App {
    @StateObject private var store = WatchStore()
    var body: some Scene { WindowGroup { WatchHome().environmentObject(store) } }
}

struct WatchHome: View {
    @EnvironmentObject private var store: WatchStore
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:10) {
                HStack { Image("KonsensLogo").resizable().scaledToFit().frame(width:30,height:30).clipShape(RoundedRectangle(cornerRadius:8)); VStack(alignment:.leading,spacing:0){Text("KONSENS").font(.caption2.bold());Text("LIVE").font(.system(size:7,weight:.black)).foregroundStyle(.mint)}; Spacer() }
                VStack(alignment:.leading,spacing:2){Text("PATRIMOINE").font(.system(size:7,weight:.bold)).foregroundStyle(.secondary);Text("\(store.wealth) K").font(.title2.monospacedDigit().bold());Text(String(format:"%+.1f%%",store.performance)).font(.caption2.bold()).foregroundStyle(store.performance>=0 ? .green:.red)}.frame(maxWidth:.infinity,alignment:.leading).padding(9).background(Color.white.opacity(.05),in:RoundedRectangle(cornerRadius:12))
                if let market=store.markets.first { VStack(alignment:.leading,spacing:4){HStack{Text("PLAY").font(.system(size:7,weight:.black)).foregroundStyle(.purple);Spacer();Text("\(market.probability)% OUI").font(.caption.bold()).foregroundStyle(.mint)};Text(market.question).font(.system(size:10,weight:.semibold)).lineLimit(3);HStack{Text(String(format:"%+.1f pt",market.movement)).font(.system(size:7)).foregroundStyle(market.movement>=0 ? .green:.red);Spacer();Text("\(market.volume) K").font(.system(size:7)).foregroundStyle(.secondary)}}.padding(9).background(Color.purple.opacity(.08),in:RoundedRectangle(cornerRadius:12)) }
                if let asset=store.assets.first { HStack{VStack(alignment:.leading){Text("FINANCE").font(.system(size:7,weight:.black)).foregroundStyle(.blue);Text(asset.symbol).font(.caption.bold());Text(asset.price.formatted(.number.precision(.fractionLength(2)))).font(.headline.monospacedDigit())};Spacer();Text(String(format:"%+.1f%%",asset.change)).font(.caption.bold()).foregroundStyle(asset.change>=0 ? .green:.red)}.padding(9).background(Color.blue.opacity(.07),in:RoundedRectangle(cornerRadius:12)) }
                Text(store.updated.map{ "Mis à jour \($0.formatted(date:.omitted,time:.shortened))" } ?? "Ouvre Konsens sur iPhone pour synchroniser").font(.system(size:7)).foregroundStyle(.secondary)
            }.padding(.horizontal,4)
        }.containerBackground(Color(red:0.025,green:0.045,blue:0.065).gradient,for:.navigation)
    }
}
