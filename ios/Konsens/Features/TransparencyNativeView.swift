import SwiftUI

struct TransparencyNativeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var whales: [WhaleRow] = []
    @State private var follows: [UUID: FollowRow] = [:]
    @State private var selected: WhaleRow?
    @State private var transactions: [ChainTransaction] = []
    @State private var provider = ""
    @State private var status = ""
    @State private var loading = true

    private var premium: Bool { store.subscriptionTier == "premium" || store.role == "admin" }

    var body: some View {
        ZStack {
            Color.konsensBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack { KonsensMark(); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").frame(width:38,height:38).background(.ultraThinMaterial,in:Circle()) }.buttonStyle(.plain) }
                    VStack(alignment:.leading,spacing:6){Eyebrow(text:"KONSENS TRANSPARENCY");Text("Whale Watch").font(.system(size:34,weight:.bold,design:.rounded));Text("Observe les mouvements d’adresses publiquement attribuées. Chaque transaction reste vérifiable sur la chaîne.").font(.subheadline).foregroundStyle(Color.konsensMuted)}
                    if !premium { Label("Lecture publique disponible · suivi et alertes réservés à Premium",systemImage:"lock.open.fill").font(.caption.bold()).foregroundStyle(Color.konsensViolet).padding(13).background(Color.konsensViolet.opacity(0.08),in:RoundedRectangle(cornerRadius:15)) }
                    if loading { ProgressView("Lecture du registre public…").tint(Color.konsensGreen).panel() }
                    else {
                        ForEach(Array(whales.prefix(12).enumerated()),id:\.element.id){index,wallet in whaleCard(index:index,wallet:wallet)}
                        if let selected { transactionSection(selected) }
                    }
                    if !status.isEmpty { Text(status).font(.caption).foregroundStyle(Color.konsensBlue).padding(12).background(Color.konsensBlue.opacity(0.06),in:RoundedRectangle(cornerRadius:13)) }
                    Text("Une adresse blockchain n’est pas une identité civile. Konsens n’affiche un nom que lorsqu’une attribution publique est sourcée.").font(.system(size:8)).foregroundStyle(Color.konsensMuted).padding(.vertical,8)
                }.padding(.horizontal,18).padding(.top,18).padding(.bottom,40)
            }
        }.preferredColorScheme(.dark).task { await load() }.refreshable { await load() }
    }

    private func whaleCard(index:Int,wallet:WhaleRow)->some View {
        VStack(spacing:10){Button{Task{await refresh(wallet)}}label:{HStack(spacing:11){Text("\(index+1)").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensViolet).frame(width:28,height:28).background(Color.konsensViolet.opacity(0.08),in:RoundedRectangle(cornerRadius:8));VStack(alignment:.leading,spacing:3){Text(wallet.display_name).font(.subheadline.bold());Text("\(wallet.wallet_kind.uppercased()) · \(short(wallet.address))").font(.system(size:8)).foregroundStyle(Color.konsensMuted);Text("Attribution \(wallet.confidence_score)% · \(wallet.transactions_30d) tx / 30 j").font(.system(size:7)).foregroundStyle(Color.konsensMuted)};Spacer();Image(systemName:"chevron.right").foregroundStyle(Color.konsensViolet)}}.buttonStyle(.plain)
            HStack{Button{Task{await toggle(wallet)}}label:{Label(follows[wallet.id] == nil ? "Suivre":"Suivi",systemImage:follows[wallet.id] == nil ? "star":"star.fill")}.buttonStyle(.bordered).tint(Color.konsensViolet).disabled(!premium);Spacer();if let source=wallet.attribution_source_url,let url=URL(string:source){Button("Source ↗"){openURL(url)}.font(.caption).buttonStyle(.plain).foregroundStyle(Color.konsensBlue)}}
            if let follow=follows[wallet.id],premium { HStack(spacing:5){Text("Alerte").font(.system(size:7)).foregroundStyle(Color.konsensMuted);ForEach([10_000.0,25_000.0,50_000.0,100_000.0],id:\.self){value in Button(value>=1000 ? "\(Int(value/1000))k€":"\(Int(value))€"){Task{await setAlert(wallet,value:value)}}.font(.system(size:7,weight:.bold)).buttonStyle(.plain).padding(.horizontal,7).padding(.vertical,5).background(follow.minimum_alert_eur == value ? Color.konsensGreen.opacity(0.16):Color.white.opacity(0.04),in:Capsule())} } }
        }.padding(14).background(selected?.id == wallet.id ? Color.konsensViolet.opacity(0.075):Color.konsensPanel,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(selected?.id == wallet.id ? Color.konsensViolet.opacity(0.24):Color.white.opacity(0.06)))
    }

    private func transactionSection(_ wallet:WhaleRow)->some View {
        VStack(alignment:.leading,spacing:11){HStack{VStack(alignment:.leading,spacing:3){Eyebrow(text:"TRANSACTIONS PUBLIQUES");Text(wallet.display_name).font(.title3.bold());Text(provider.isEmpty ? wallet.address : "\(provider) · \(short(wallet.address))").font(.system(size:7)).foregroundStyle(Color.konsensMuted)};Spacer();Button{Task{await refresh(wallet)}}label:{Image(systemName:"arrow.clockwise")}.buttonStyle(.bordered).tint(Color.konsensBlue)}
            if transactions.isEmpty { Text("Aucune transaction chargée pour le moment.").font(.caption).foregroundStyle(Color.konsensMuted).padding(.vertical,20) }
            ForEach(transactions.prefix(20)){tx in Button{if let url=URL(string:tx.explorerUrl){openURL(url)}}label:{HStack(spacing:10){Image(systemName:tx.direction == "in" ? "arrow.down.left":"arrow.up.right").foregroundStyle(tx.direction == "in" ? Color.konsensPositive:Color.konsensGold).frame(width:30,height:30).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:9));VStack(alignment:.leading,spacing:2){Text("\(tx.direction == "in" ? "Réception":"Envoi") · \(tx.assetSymbol)").font(.caption.bold());Text("\(tx.assetAmount.formatted(.number.precision(.fractionLength(0...6)))) \(tx.assetSymbol)").font(.system(size:8)).foregroundStyle(Color.konsensMuted);Text(shortDate(tx.blockTime)).font(.system(size:7)).foregroundStyle(Color.konsensMuted)};Spacer();if let value=tx.estimatedValueEUR{Text(value.formatted(.currency(code:"EUR").precision(.fractionLength(0)))).font(.caption.monospacedDigit().bold())};Image(systemName:"arrow.up.forward.square").font(.caption).foregroundStyle(Color.konsensBlue)}}.buttonStyle(.plain).padding(.vertical,5) }
        }.panel()
    }

    private func load() async {
        loading=true
        struct P:Encodable{let p_limit:Int}
        let rows:[WhaleRow]=(try? await store.supabase.rpc("get_whale_leaderboard",params:P(p_limit:25)).execute().value) ?? []
        whales=rows
        if let userID=store.supabase.auth.currentUser?.id { let f:[FollowRow]=(try? await store.supabase.from("wallet_follows").select("wallet_id,minimum_alert_eur,notifications_enabled").eq("user_id",value:userID).execute().value) ?? [];follows=Dictionary(uniqueKeysWithValues:f.map{($0.wallet_id,$0)}) }
        if selected == nil { selected=rows.first }
        loading=false
    }
    private func refresh(_ wallet:WhaleRow) async {
        selected=wallet;transactions=[];status="Lecture de la blockchain…"
        guard var c=URLComponents(string:"https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/blockchain-data") else{return};c.queryItems=[URLQueryItem(name:"wallet_id",value:wallet.id.uuidString),URLQueryItem(name:"address",value:wallet.address)];guard let url=c.url,let token=store.supabase.auth.currentSession?.accessToken else{return}
        var request=URLRequest(url:url);request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization");request.setValue("sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",forHTTPHeaderField:"apikey")
        do{let(data,response)=try await URLSession.shared.data(for:request);guard(response as? HTTPURLResponse)?.statusCode==200 else{throw URLError(.badServerResponse)};let decoded=try JSONDecoder().decode(ChainEnvelope.self,from:data);provider=decoded.provider;transactions=decoded.transactions;status=decoded.persistedForAlerts ? "Synchronisé · alertes Premium armées":"Flux public synchronisé"}catch{status="Flux blockchain momentanément indisponible"}
    }
    private func toggle(_ wallet:WhaleRow) async {
        guard premium,let userID=store.supabase.auth.currentUser?.id else{store.showToast("Premium requis pour les alertes blockchain");return}
        do{if follows[wallet.id] != nil{try await store.supabase.from("wallet_follows").delete().eq("user_id",value:userID).eq("wallet_id",value:wallet.id).execute()}else{struct Insert:Encodable{let user_id:UUID;let wallet_id:UUID;let minimum_alert_eur:Double;let notifications_enabled:Bool};try await store.supabase.from("wallet_follows").insert(Insert(user_id:userID,wallet_id:wallet.id,minimum_alert_eur:25_000,notifications_enabled:true)).execute()};await load()}catch{store.showToast("Impossible de modifier le suivi")}
    }
    private func setAlert(_ wallet:WhaleRow,value:Double) async { struct P:Encodable{let p_wallet_id:UUID;let p_minimum_alert_eur:Double;let p_enabled:Bool};do{_ = try await store.supabase.rpc("set_wallet_alert",params:P(p_wallet_id:wallet.id,p_minimum_alert_eur:value,p_enabled:true)).execute();await load();store.showToast("Alerte réglée") }catch{store.showToast("Réglage impossible")} }
    private func short(_ value:String)->String{guard value.count>14 else{return value};return "\(value.prefix(7))…\(value.suffix(5))"}
    private func shortDate(_ raw:String)->String{let f=ISO8601DateFormatter();guard let d=f.date(from:raw) else{return raw};return d.formatted(date:.abbreviated,time:.shortened)}
}

private struct WhaleRow:Decodable,Identifiable{let id:UUID;let chain:String;let address:String;let display_name:String;let wallet_kind:String;let attribution_type:String;let confidence_score:Int;let attribution_source_url:String?;let native_symbol:String?;let observable_balance_native:Double?;let observable_value_eur:Double?;let rank_hint:Int?;let volume_30d_eur:Double;let transactions_30d:Int;let last_activity:String?;let source_updated_at:String?}
private struct FollowRow:Decodable{let wallet_id:UUID;let minimum_alert_eur:Double;let notifications_enabled:Bool}
private struct ChainEnvelope:Decodable{let provider:String;let transactions:[ChainTransaction];let persistedForAlerts:Bool}
private struct ChainTransaction:Decodable,Identifiable{let providerEventId:String;let hash:String;let from:String;let to:String;let eventType:String;let direction:String;let assetSymbol:String;let assetAmount:Double;let estimatedValueEUR:Double?;let blockTime:String;let blockNumber:String;let explorerUrl:String;var id:String{providerEventId}}
