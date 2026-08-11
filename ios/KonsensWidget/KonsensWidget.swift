import WidgetKit
import SwiftUI
import AppIntents

enum WidgetUniverse:String,AppEnum{
    case today,play,finance,mixed
    static var typeDisplayRepresentation=TypeDisplayRepresentation(name:"Vue Konsens")
    static var caseDisplayRepresentations:[WidgetUniverse:DisplayRepresentation]=[
        WidgetUniverse.today:"Aujourd’hui",
        WidgetUniverse.play:"Prédictions",
        WidgetUniverse.finance:"Finance",
        WidgetUniverse.mixed:"Prédictions + Finance"
    ]
}
struct KonsensWidgetIntent:WidgetConfigurationIntent{
    static var title:LocalizedStringResource="Contenu du widget"
    static var description=IntentDescription("Affiche ton parcours du jour, tes prédictions ou les marchés suivis.")
    @Parameter(title:"Afficher",default:WidgetUniverse.today)var universe:WidgetUniverse
}
struct WidgetMarket:Codable,Hashable{let question:String;let category:String;let probability:Int;let volume:Int;let movement:Double}
struct WidgetAsset:Codable,Hashable{let symbol:String;let name:String;let price:Double;let change:Double;let currency:String}
struct KonsensWidgetEntry:TimelineEntry{
    let date:Date
    let configuration:KonsensWidgetIntent
    let wealth:Int
    let performance:Double
    let score:Int
    let archetype:String
    let dailyTitle:String
    let dailyNext:String
    let dailyProgress:Int
    let markets:[WidgetMarket]
    let assets:[WidgetAsset]
}
struct KonsensWidgetProvider:AppIntentTimelineProvider{
    func placeholder(in context:Context)->KonsensWidgetEntry{.init(date:.now,configuration:KonsensWidgetIntent(),wealth:1000,performance:0,score:62,archetype:"Décideur équilibré",dailyTitle:"Ton Konsens du jour",dailyNext:"Donne ta probabilité sur le marché du jour",dailyProgress:25,markets:[.init(question:"Bitcoin dépassera-t-il son prochain seuil ?",category:"Crypto",probability:51,volume:0,movement:2.4)],assets:[.init(symbol:"AAPL",name:"Apple",price:221.45,change:1.3,currency:"USD")])}
    func snapshot(for configuration:KonsensWidgetIntent,in context:Context)async->KonsensWidgetEntry{entry(configuration)}
    func timeline(for configuration:KonsensWidgetIntent,in context:Context)async->Timeline<KonsensWidgetEntry>{Timeline(entries:[entry(configuration)],policy:.after(Date().addingTimeInterval(15*60)))}
    private func entry(_ configuration:KonsensWidgetIntent)->KonsensWidgetEntry{
        let d=UserDefaults(suiteName:"group.com.konsens.beta")
        let wealth=d?.integer(forKey:"konsens_widget_wealth") ?? 1000
        let performance=d?.double(forKey:"konsens_widget_performance") ?? 0
        let score=d?.integer(forKey:"konsens_widget_score") ?? 0
        let archetype=d?.string(forKey:"konsens_widget_archetype") ?? "Profil en construction"
        let dailyTitle=d?.string(forKey:"konsens_widget_daily_title") ?? "Ton Konsens du jour"
        let dailyNext=d?.string(forKey:"konsens_widget_daily_next") ?? "Ouvre Konsens pour démarrer"
        let dailyProgress=d?.integer(forKey:"konsens_widget_daily_progress") ?? 0
        let md=d?.data(forKey:"konsens_widget_markets"),ad=d?.data(forKey:"konsens_widget_assets")
        let markets=md.flatMap{try? JSONDecoder().decode([WidgetMarket].self,from:$0)} ?? []
        let assets=ad.flatMap{try? JSONDecoder().decode([WidgetAsset].self,from:$0)} ?? []
        return .init(date:.now,configuration:configuration,wealth:wealth==0 ? 1000:wealth,performance:performance,score:score,archetype:archetype,dailyTitle:dailyTitle,dailyNext:dailyNext,dailyProgress:dailyProgress,markets:markets,assets:assets)
    }
}
struct KonsensWidgetView:View{
    @Environment(\.widgetFamily)private var family
    let entry:KonsensWidgetEntry
    private var universe:WidgetUniverse{entry.configuration.universe}
    var body:some View{Group{switch family{case .accessoryCircular:accessoryCircle;case .accessoryRectangular:accessoryRect;case .accessoryInline:accessoryInline;default:standard}}.containerBackground(for:.widget){background}.widgetURL(destination)}
    private var destination:URL?{switch universe{case .today:URL(string:"konsens://today");case .finance:URL(string:"konsens://invest");case .play,.mixed:URL(string:"konsens://play")}}
    private var standard:some View{VStack(alignment:.leading,spacing:9){HStack{mark;VStack(alignment:.leading,spacing:0){Text("KONSENS").font(.system(size:9,weight:.black,design:.rounded)).tracking(1);Text(modeTitle).font(.system(size:7,weight:.bold)).foregroundStyle(.secondary)};Spacer();if universe == .today{Text("\(entry.score)").font(.caption.monospacedDigit().bold());Text("/100").font(.system(size:6)).foregroundStyle(.secondary)}else if universe != .play{Text(entry.wealth.formatted()).font(.caption.monospacedDigit().bold());Text("K").font(.system(size:7,weight:.bold)).foregroundStyle(.secondary)}};if family == .systemSmall{smallContent}else{mediumContent};Spacer(minLength:0);HStack{Circle().fill(Color.mint).frame(width:5,height:5);Text(universe == .today ? "Entraînement quotidien":"Koins fictifs · 15 min").font(.system(size:6)).foregroundStyle(.secondary);Spacer()}}.padding(3)}
    @ViewBuilder private var smallContent:some View{switch universe{case .today:TodayRow(entry:entry,compact:false);case .play:if let m=entry.markets.first{PlayRow(market:m,large:true)}else{empty("Aucune prédiction")};case .finance:if let a=entry.assets.first{FinanceRow(asset:a,large:true)}else{empty("Marché en attente")};case .mixed:if let m=entry.markets.first{PlayRow(market:m,large:false)};if let a=entry.assets.first{FinanceRow(asset:a,large:false)}}}
    @ViewBuilder private var mediumContent:some View{switch universe{case .today:HStack(spacing:10){TodayRow(entry:entry,compact:true).frame(maxWidth:.infinity);Rectangle().fill(Color.white.opacity(0.08)).frame(width:1);VStack(alignment:.leading,spacing:5){Text("PROCHAINE ÉTAPE").font(.system(size:6,weight:.black)).foregroundStyle(.mint);Text(entry.dailyNext).font(.system(size:11,weight:.semibold)).lineLimit(3);Text("\(entry.dailyProgress)% terminé").font(.system(size:7)).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)};case .play:HStack(spacing:8){ForEach(Array(entry.markets.prefix(2).enumerated()),id:\.offset){_,m in PlayRow(market:m,large:false)}};case .finance:HStack(spacing:8){ForEach(Array(entry.assets.prefix(3).enumerated()),id:\.offset){_,a in FinanceRow(asset:a,large:false)}};case .mixed:HStack(spacing:8){if let m=entry.markets.first{PlayRow(market:m,large:false).frame(maxWidth:.infinity)};Rectangle().fill(Color.white.opacity(0.08)).frame(width:1);VStack(spacing:6){ForEach(Array(entry.assets.prefix(2).enumerated()),id:\.offset){_,a in FinanceRow(asset:a,large:false)}}.frame(maxWidth:.infinity)}}}
    private var accessoryCircle:some View{ZStack{Image("KonsensLogo").resizable().scaledToFit().clipShape(Circle());Text(universe == .today ? "\(entry.score)":"\(entry.markets.first?.probability ?? 0)%").font(.system(size:9,weight:.black)).padding(3).background(.black.opacity(0.7),in:Capsule()).offset(y:18)}}
    private var accessoryRect:some View{HStack(spacing:7){Image("KonsensLogo").resizable().scaledToFit().frame(width:26,height:26).clipShape(RoundedRectangle(cornerRadius:7));if universe == .today{VStack(alignment:.leading){Text("Score \(entry.score)/100").font(.caption.bold());Text(entry.dailyNext).font(.caption2).lineLimit(1)}}else if universe == .finance,let a=entry.assets.first{VStack(alignment:.leading){Text(a.symbol).font(.caption.bold());Text(String(format:"%+.1f%%",a.change)).font(.caption2).foregroundStyle(a.change>=0 ? .green:.red)}}else if let m=entry.markets.first{VStack(alignment:.leading){Text(m.category).font(.caption2);Text("OUI \(m.probability)%").font(.caption.bold())}};Spacer()}}
    private var accessoryInline:some View{switch universe{case .today:Text("Konsens \(entry.score)/100 · \(entry.dailyProgress)% du parcours");case .finance:if let a=entry.assets.first{Text("Konsens · \(a.symbol) \(String(format:"%+.1f%%",a.change))")}else{Text("Konsens Finance")};case .play,.mixed:if let m=entry.markets.first{Text("Konsens · \(m.probability)% OUI")}else{Text("Konsens Live")}}}
    private var modeTitle:String{switch universe{case .today:"AUJOURD’HUI";case .play:"PRÉDIRE";case .finance:"DÉCIDER";case .mixed:"PRÉDIRE · DÉCIDER"}}
    private var mark:some View{Image("KonsensLogo").resizable().scaledToFit().frame(width:31,height:31).clipShape(RoundedRectangle(cornerRadius:9))}
    private var background:some View{ZStack{Color(red:0.025,green:0.045,blue:0.065);if universe == .today{RadialGradient(colors:[Color.mint.opacity(0.16),.clear],center:.topTrailing,startRadius:0,endRadius:160)}else if universe != .finance{RadialGradient(colors:[Color.purple.opacity(0.18),.clear],center:.topTrailing,startRadius:0,endRadius:160)};if universe != .play{LinearGradient(colors:[Color.blue.opacity(0.05),.clear],startPoint:.bottomLeading,endPoint:.topTrailing)}}}
    private func empty(_ text:String)->some View{Text(text).font(.caption).foregroundStyle(.secondary)}
}
private struct TodayRow:View{let entry:KonsensWidgetEntry;let compact:Bool;var body:some View{VStack(alignment:.leading,spacing:6){Text(entry.dailyTitle).font(.system(size:compact ? 10:12,weight:.bold)).lineLimit(1);HStack(alignment:.firstTextBaseline){Text("\(entry.score)").font(.system(size:compact ? 28:34,weight:.black,design:.rounded)).foregroundStyle(.mint);Text("/100").font(.caption2).foregroundStyle(.secondary)};Text(entry.archetype).font(.system(size:7,weight:.bold)).foregroundStyle(.secondary).lineLimit(1);ProgressView(value:Double(entry.dailyProgress),total:100).tint(.mint);Text(entry.dailyNext).font(.system(size:7)).lineLimit(compact ? 1:2).foregroundStyle(.secondary)}}
private struct PlayRow:View{let market:WidgetMarket;let large:Bool;var body:some View{VStack(alignment:.leading,spacing:5){HStack{Text(market.category.uppercased()).font(.system(size:6,weight:.bold)).foregroundStyle(.purple);Spacer();Text("\(market.probability)%").font((large ? Font.title2:Font.caption).monospacedDigit().bold()).foregroundStyle(.mint)};Text(market.question).font(.system(size:large ? 11:9,weight:.semibold)).lineLimit(large ? 3:2);HStack{Text("OUI").font(.system(size:6,weight:.black)).foregroundStyle(.mint);Text("x\(String(format:"%.2f",1/max(0.02,Double(market.probability)/100)))").font(.system(size:7,weight:.bold)).foregroundStyle(.secondary);if abs(market.movement)>=0.05{Text(String(format:"%@%.1f pt",market.movement>0 ? "+":"",market.movement)).font(.system(size:6,weight:.bold)).foregroundStyle(market.movement>=0 ? Color.mint:Color.red)};Spacer();Text("\(market.volume) K").font(.system(size:6)).foregroundStyle(.secondary)}}.padding(8).background(Color.purple.opacity(0.07),in:RoundedRectangle(cornerRadius:11))}}
private struct FinanceRow:View{let asset:WidgetAsset;let large:Bool;var body:some View{HStack(alignment:.center,spacing:6){VStack(alignment:.leading,spacing:2){Text(asset.symbol).font(.system(size:large ? 12:9,weight:.black,design:.monospaced));Text(asset.price.formatted(.number.precision(.fractionLength(2)))).font(.system(size:large ? 18:11,weight:.bold,design:.monospaced));Text(asset.currency).font(.system(size:6)).foregroundStyle(.secondary)};Spacer(minLength:2);Text(String(format:"%+.1f%%",asset.change)).font(.system(size:large ? 9:7,weight:.bold)).foregroundStyle(asset.change>=0 ? Color.mint:Color.red)}.padding(8).background(Color.blue.opacity(0.055),in:RoundedRectangle(cornerRadius:11))}}
@main struct KonsensWidget:Widget{let kind="KonsensWidget";var body:some WidgetConfiguration{AppIntentConfiguration(kind:kind,intent:KonsensWidgetIntent.self,provider:KonsensWidgetProvider()){entry in KonsensWidgetView(entry:entry)}.configurationDisplayName("Konsens — Aujourd’hui").description("Ton Konsens Score, ta prochaine étape, tes prédictions ou les marchés suivis.").supportedFamilies([.systemSmall,.systemMedium,.accessoryCircular,.accessoryRectangular,.accessoryInline])}}
