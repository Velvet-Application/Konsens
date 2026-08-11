import SwiftUI
import WidgetKit

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore
    @State private var journey: DailyJourney?
    @State private var score: KonsensScore?
    @State private var insights: [CoachInsight] = []
    @State private var replays: [ReplayScenario] = []
    @State private var leagues: [LeagueSummary] = []
    @State private var leaders: [UUID: [LeagueLeaderRow]] = [:]
    @State private var prediction = 55.0
    @State private var decision = "observe"
    @State private var replayChoice: [UUID: String] = [:]
    @State private var replayConfidence: [UUID: Double] = [:]
    @State private var replayResults: [UUID: ReplayResult] = [:]
    @State private var whatIfAssetID: UUID?
    @State private var whatIfAmount = 100.0
    @State private var whatIfResult: WhatIfResult?
    @State private var status = ""
    @State private var loading = true

    private var completed: Set<String> { Set(journey?.completed_steps ?? []) }
    private var progress: Int { guard let journey, !journey.steps.isEmpty else { return 0 }; return Int((Double(completed.count) / Double(journey.steps.count) * 100).rounded()) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                TodayHero(score: score, username: store.username)
                if loading { ProgressView("Préparation de ton Konsens du jour…").tint(Color.konsensGreen).panel() }
                if let journey { DailyJourneyCard(journey: journey, completed: completed, progress: progress, prediction: $prediction, decision: $decision, busy: loading, action: handleStep) }
                if let score { ScoreCard(score: score) }
                CoachCard(insights: insights, premium: store.subscriptionTier == "premium", navigate: navigate)
                ReplayCard(scenarios: replays, choices: $replayChoice, confidence: $replayConfidence, results: replayResults, submit: submitReplay)
                LeagueCard(leagues: leagues, leaders: leaders, join: joinLeague)
                WhatIfNativeCard(assets: store.assets, selectedAssetID: $whatIfAssetID, amount: $whatIfAmount, result: whatIfResult, premium: store.subscriptionTier == "premium", run: runWhatIf)
                WorldsCard()
                if store.subscriptionTier == "free" { SponsoredCard() }
                ProfileShareCard(score: score, username: store.username)
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(Color.konsensBlue).padding(12).background(Color.konsensBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 13)) }
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        loading = true
        async let dailyTask: [DailyJourney] = (try? await store.supabase.rpc("get_my_daily_journey").execute().value) ?? []
        struct ScoreParams: Encodable { let p_persist: Bool }
        async let scoreTask: [KonsensScore] = (try? await store.supabase.rpc("get_my_konsens_score", params: ScoreParams(p_persist: true)).execute().value) ?? []
        async let coachTask: [CoachInsight] = (try? await store.supabase.rpc("refresh_my_coach_insights").execute().value) ?? []
        async let replayTask: [ReplayScenario] = (try? await store.supabase.from("replay_scenarios").select("id,title,era,setup,known_at_time,choices,reveal_text,lesson,source_urls,difficulty,position").eq("active", value: true).order("position").execute().value) ?? []
        async let leagueTask: [LeagueSummary] = (try? await store.supabase.rpc("get_discoverable_leagues").execute().value) ?? []
        let (dailyRows, scoreRows, coachRows, replayRows, leagueRows) = await (dailyTask, scoreTask, coachTask, replayTask, leagueTask)
        journey = dailyRows.first
        score = scoreRows.first
        insights = coachRows
        replays = replayRows
        leagues = leagueRows
        if whatIfAssetID == nil { whatIfAssetID = store.assets.first?.id }
        for league in leagueRows where league.is_member { await loadLeague(league.id) }
        syncJourneyWidget()
        loading = false
    }

    private func handleStep(_ step: DailyStep) {
        if step.type == "learn" { store.selectedTab = .learn; return }
        Task {
            loading = true
            struct Params: Encodable { let p_step_key: String; let p_answer: [String: String] }
            var answer: [String: String] = ["completed": "true"]
            if step.type == "predict" { answer = ["probability": String(Int(prediction)), "community_probability": String(step.community_probability ?? 0)] }
            if step.type == "decide" { answer = ["decision": decision, "symbol": step.symbol ?? ""] }
            _ = try? await store.supabase.rpc("complete_daily_step", params: Params(p_step_key: step.key, p_answer: answer)).execute()
            status = "Étape validée · ton profil de décision se met à jour."
            await load()
        }
    }

    private func submitReplay(_ scenario: ReplayScenario) {
        guard let choice = replayChoice[scenario.id] else { status = "Choisis une décision avant de révéler la suite."; return }
        Task {
            struct Params: Encodable { let p_scenario_id: UUID; let p_choice_key: String; let p_confidence: Int; let p_reflection: String? }
            let params = Params(p_scenario_id: scenario.id, p_choice_key: choice, p_confidence: Int(replayConfidence[scenario.id] ?? 60), p_reflection: nil)
            let rows: [ReplayResult] = (try? await store.supabase.rpc("submit_replay_attempt", params: params).execute().value) ?? []
            if let result = rows.first { replayResults[scenario.id] = result; status = "Replay enregistré dans ta progression."; await load() }
        }
    }

    private func joinLeague(_ league: LeagueSummary) {
        Task {
            struct Params: Encodable { let p_join_code: String }
            _ = try? await store.supabase.rpc("join_league_by_code", params: Params(p_join_code: league.join_code)).execute()
            status = "Bienvenue dans \(league.name)."
            await load()
        }
    }

    private func loadLeague(_ id: UUID) async {
        struct Params: Encodable { let p_league_id: UUID }
        let rows: [LeagueLeaderRow] = (try? await store.supabase.rpc("get_league_leaderboard", params: Params(p_league_id: id)).execute().value) ?? []
        leaders[id] = rows
    }

    private func runWhatIf() {
        guard let id = whatIfAssetID else { return }
        Task {
            struct Params: Encodable { let p_asset_id: UUID; let p_koins: Double }
            let rows: [WhatIfResult] = (try? await store.supabase.rpc("simulate_asset_what_if", params: Params(p_asset_id: id, p_koins: whatIfAmount)).execute().value) ?? []
            whatIfResult = rows.first
            if rows.isEmpty { status = "L’historique capturé est encore insuffisant pour cet actif." }
        }
    }

    private func navigate(_ route: String?) {
        switch route { case "play": store.selectedTab = .play; case "invest": store.selectedTab = .invest; case "learn": store.selectedTab = .learn; default: store.selectedTab = .profile }
    }

    private func syncJourneyWidget() {
        guard let defaults = UserDefaults(suiteName: "group.com.konsens.beta") else { return }
        defaults.set(score?.total_score ?? 0, forKey: "konsens_widget_score")
        defaults.set(score?.archetype ?? "Profil en construction", forKey: "konsens_widget_archetype")
        defaults.set(journey?.title ?? "Ton Konsens du jour", forKey: "konsens_widget_daily_title")
        defaults.set(journey?.steps.first(where: { !completed.contains($0.key) })?.title ?? "Parcours terminé", forKey: "konsens_widget_daily_next")
        defaults.set(progress, forKey: "konsens_widget_daily_progress")
        WidgetCenter.shared.reloadAllTimelines()
        WatchBridge.shared.sendSnapshot()
    }
}

private struct TodayHero: View {
    let score: KonsensScore?; let username: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "KONSENS · ENTRAÎNEMENT DU JOUR")
            Text("Bonjour \(username).")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("Chaque jour, entraîne ta capacité à prendre de meilleures décisions avec l’argent.")
                .font(.title3.bold())
            Text("Comprendre → prédire → décider → apprendre. Le patrimoine est un résultat, pas le programme.")
                .font(.subheadline).foregroundStyle(Color.konsensMuted)
            if let score { HStack { Text("Konsens Score").font(.caption.bold()); Spacer(); Text("\(score.total_score)/100 · \(score.archetype)").font(.caption.monospacedDigit().bold()).foregroundStyle(Color.konsensGreen) }.padding(11).background(Color.konsensGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 13)) }
        }
    }
}

private struct DailyJourneyCard: View {
    let journey: DailyJourney; let completed: Set<String>; let progress: Int
    @Binding var prediction: Double; @Binding var decision: String
    let busy: Bool; let action: (DailyStep) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { VStack(alignment: .leading, spacing: 3) { Eyebrow(text: "AUJOURD’HUI · ENVIRON 5 MIN"); Text(journey.title).font(.title2.bold()); Text(journey.subtitle).font(.caption).foregroundStyle(Color.konsensMuted) }; Spacer(); ZStack { Circle().stroke(Color.white.opacity(0.07), lineWidth: 6); Circle().trim(from: 0, to: CGFloat(progress)/100).stroke(Color.konsensGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90)); Text("\(progress)%").font(.caption2.bold()) }.frame(width: 52, height: 52) }
            ForEach(Array(journey.steps.enumerated()), id: \.element.key) { index, step in
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Text(completed.contains(step.key) ? "✓" : String(format: "%02d", index + 1)).font(.caption.monospacedDigit().bold()).foregroundStyle(completed.contains(step.key) ? Color.konsensPositive : Color.konsensBlue); Text(step.eyebrow).font(.system(size: 8, weight: .black)).tracking(1).foregroundStyle(Color.konsensGreen); Spacer(); Text("\(step.minutes) min").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }
                    Text(step.title).font(.headline)
                    Text(step.body).font(.caption).foregroundStyle(Color.konsensMuted)
                    if step.type == "predict" && !completed.contains(step.key) { VStack(spacing: 5) { HStack { Text("Ta probabilité").font(.caption2); Spacer(); Text("\(Int(prediction))%").font(.caption.monospacedDigit().bold()) }; Slider(value: $prediction, in: 5...95, step: 5).tint(Color.konsensViolet); Text("Consensus : \(step.community_probability ?? 0)%").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) } }
                    if step.type == "decide" && !completed.contains(step.key) { HStack(spacing: 6) { ChoiceButton(id: "buy", label: "J’investis", selected: $decision); ChoiceButton(id: "observe", label: "J’observe", selected: $decision); ChoiceButton(id: "avoid", label: "J’évite", selected: $decision) } }
                    if !completed.contains(step.key) { Button(step.type == "learn" ? "Ouvrir Academy →" : step.type == "predict" ? "Enregistrer ma conviction" : step.type == "decide" ? "Valider ma décision" : "J’ai compris") { action(step) }.buttonStyle(.plain).font(.caption.bold()).foregroundStyle(Color.konsensBackground).frame(maxWidth: .infinity).padding(10).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 11)).disabled(busy) }
                }.padding(13).background(completed.contains(step.key) ? Color.konsensPositive.opacity(0.035) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))
            }
        }.panel()
    }
}
private struct ChoiceButton: View { let id:String;let label:String;@Binding var selected:String;var body:some View{Button(label){selected=id}.font(.system(size:8,weight:.bold)).buttonStyle(.plain).frame(maxWidth:.infinity).padding(8).background(selected==id ? Color.konsensBlue.opacity(0.16):Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:9)).foregroundStyle(selected==id ? Color.konsensBlue:Color.konsensMuted)} }

private struct ScoreCard: View {
    let score: KonsensScore
    private var dims: [(String,Int)] { [("Connaissance",score.knowledge_score),("Calibration",score.calibration_score),("Risque",score.risk_score),("Discipline",score.discipline_score),("Régularité",score.consistency_score),("Résultat",score.performance_score)] }
    var body: some View { VStack(alignment:.leading,spacing:14){HStack{VStack(alignment:.leading,spacing:3){Eyebrow(text:"TON PROFIL DE DÉCISION");Text(score.archetype).font(.title3.bold());Text("Le résultat financier ne représente qu’une partie du score.").font(.caption).foregroundStyle(Color.konsensMuted)};Spacer();Text("\(score.total_score)").font(.system(size:38,weight:.black,design:.rounded)).foregroundStyle(Color.konsensGreen)};ForEach(dims,id:\.0){name,value in VStack(spacing:4){HStack{Text(name).font(.caption2.bold());Spacer();Text("\(value)").font(.caption2.monospacedDigit().bold())};GeometryReader{geo in ZStack(alignment:.leading){Capsule().fill(Color.white.opacity(0.05));Capsule().fill(LinearGradient(colors:[Color.konsensGreen,Color.konsensBlue],startPoint:.leading,endPoint:.trailing)).frame(width:geo.size.width*CGFloat(value)/100)}}.frame(height:5)}}}.panel() }
}

private struct CoachCard: View {
    let insights:[CoachInsight];let premium:Bool;let navigate:(String?)->Void
    var body: some View { VStack(alignment:.leading,spacing:12){HStack{VStack(alignment:.leading,spacing:3){Eyebrow(text:"KONSENS COACH");Text("Ce que tes décisions disent de toi.").font(.title3.bold())};Spacer();Text(premium ? "PREMIUM":"ESSENTIEL").font(.system(size:7,weight:.black)).foregroundStyle(Color.konsensViolet)};if insights.isEmpty{Text("Documente quelques décisions : le Coach deviendra progressivement plus personnel.").font(.caption).foregroundStyle(Color.konsensMuted)}else{ForEach(insights.prefix(4)){insight in VStack(alignment:.leading,spacing:6){Text(insight.premium_only ? "PREMIUM":"ANALYSE").font(.system(size:7,weight:.black)).foregroundStyle(Color.konsensViolet);Text(insight.title).font(.headline);Text(insight.body).font(.caption).foregroundStyle(Color.konsensMuted);if insight.action_route != nil{Button("\(insight.action_label ?? "Agir") →"){navigate(insight.action_route)}.font(.caption.bold()).buttonStyle(.plain).foregroundStyle(Color.konsensGreen)}}.padding(12).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:14))}}}.panel() }
}

private struct ReplayCard: View {
    let scenarios:[ReplayScenario];@Binding var choices:[UUID:String];@Binding var confidence:[UUID:Double];let results:[UUID:ReplayResult];let submit:(ReplayScenario)->Void
    var body:some View{VStack(alignment:.leading,spacing:12){Eyebrow(text:"REPLAY DU RÉEL");Text("Décide avant de connaître la suite.").font(.title3.bold());ForEach(scenarios.prefix(3)){scenario in VStack(alignment:.leading,spacing:9){Text("\(scenario.era.uppercased()) · \(scenario.difficulty.uppercased())").font(.system(size:7,weight:.black)).foregroundStyle(Color.konsensBlue);Text(scenario.title).font(.headline);Text(scenario.setup).font(.caption).foregroundStyle(Color.konsensMuted);if let result=results[scenario.id]{Text("\(result.score)/100").font(.title2.bold()).foregroundStyle(Color.konsensGreen);Text(result.reveal_text).font(.caption);Text(result.lesson).font(.caption.bold()).foregroundStyle(Color.konsensMuted)}else{ForEach(scenario.choices,id:\.key){choice in Button(choice.label){choices[scenario.id]=choice.key}.font(.caption).buttonStyle(.plain).frame(maxWidth:.infinity,alignment:.leading).padding(9).background(choices[scenario.id]==choice.key ? Color.konsensBlue.opacity(0.14):Color.white.opacity(0.03),in:RoundedRectangle(cornerRadius:10))};HStack{Text("Confiance").font(.caption2);Slider(value:Binding(get:{confidence[scenario.id] ?? 60},set:{confidence[scenario.id]=$0}),in:10...95,step:5).tint(Color.konsensBlue);Text("\(Int(confidence[scenario.id] ?? 60))%").font(.caption2.monospacedDigit())};Button("Révéler la suite"){submit(scenario)}.font(.caption.bold()).buttonStyle(.plain).foregroundStyle(.white).frame(maxWidth:.infinity).padding(10).background(Color.konsensBlue,in:RoundedRectangle(cornerRadius:11))}}.padding(13).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:15))}}.panel()}
}

private struct LeagueCard: View {
    let leagues:[LeagueSummary];let leaders:[UUID:[LeagueLeaderRow]];let join:(LeagueSummary)->Void
    var body:some View{VStack(alignment:.leading,spacing:12){Eyebrow(text:"LIGUES KONSENS");Text("Se comparer sur la qualité de décision.").font(.title3.bold());ForEach(leagues){league in VStack(alignment:.leading,spacing:7){HStack{VStack(alignment:.leading){Text(league.name).font(.headline);Text("\(league.member_count) membres · \(league.ranking_dimension)").font(.system(size:8)).foregroundStyle(Color.konsensMuted)};Spacer();if league.is_member{Text("MEMBRE").font(.system(size:7,weight:.black)).foregroundStyle(Color.konsensGreen)}else{Button("Rejoindre"){join(league)}.font(.caption2.bold()).buttonStyle(.bordered).tint(Color.konsensGreen)}};Text(league.description).font(.caption).foregroundStyle(Color.konsensMuted);ForEach((leaders[league.id] ?? []).prefix(4)){row in HStack{Text("#\(row.rank)").font(.caption2.monospacedDigit()).foregroundStyle(Color.konsensMuted);Text("@\(row.username)").font(.caption.bold());Spacer();Text(row.archetype).font(.system(size:7)).foregroundStyle(Color.konsensMuted);Text("\(row.konsens_score)").font(.caption.monospacedDigit().bold())}}}.padding(12).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:14))}}.panel()}
}

private struct WhatIfNativeCard: View {
    let assets:[AssetQuote];@Binding var selectedAssetID:UUID?;@Binding var amount:Double;let result:WhatIfResult?;let premium:Bool;let run:()->Void
    var body:some View{VStack(alignment:.leading,spacing:12){HStack{VStack(alignment:.leading,spacing:3){Eyebrow(text:"PORTFOLIO LAB · ET SI…");Text("Rejoue l’historique capturé.").font(.title3.bold())};Spacer();Text(premium ? "PREMIUM":"LAB").font(.system(size:7,weight:.black)).foregroundStyle(Color.konsensViolet)};Menu{ForEach(assets){asset in Button("\(asset.symbol) · \(asset.name)"){selectedAssetID=asset.id}}}label:{HStack{Text(assets.first(where:{$0.id==selectedAssetID})?.symbol ?? "Choisir un actif").font(.headline);Spacer();Image(systemName:"chevron.down")}.padding(11).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:11))};HStack{Text("\(Int(amount)) K").font(.caption.monospacedDigit().bold());Slider(value:$amount,in:25...500,step:25).tint(Color.konsensBlue)};Button("Simuler →",action:run).font(.caption.bold()).buttonStyle(.plain).foregroundStyle(.white).frame(maxWidth:.infinity).padding(10).background(Color.konsensBlue,in:RoundedRectangle(cornerRadius:11));if let result{HStack{VStack(alignment:.leading){Text("Départ").font(.caption2).foregroundStyle(Color.konsensMuted);Text("\(result.invested_koins.formatted(.number.precision(.fractionLength(0)))) K").font(.headline)};Spacer();Image(systemName:"arrow.right").foregroundStyle(Color.konsensMuted);Spacer();VStack(alignment:.trailing){Text("Dernière donnée").font(.caption2).foregroundStyle(Color.konsensMuted);Text("\(result.current_value_koins.formatted(.number.precision(.fractionLength(1)))) K").font(.headline);Text(String(format:"%+.1f%%",result.gain_loss_percent)).font(.caption.bold()).foregroundStyle(result.gain_loss_koins>=0 ? Color.konsensPositive:Color.konsensNegative)}}.padding(11).background(Color.white.opacity(0.03),in:RoundedRectangle(cornerRadius:12));if result.history_limited{Text("Historique Konsens encore court : la simulation porte uniquement sur les données déjà capturées.").font(.system(size:8)).foregroundStyle(Color.konsensMuted)}}}.panel()}
}

private struct WorldsCard: View { @EnvironmentObject private var store:AppStore;var body:some View{VStack(alignment:.leading,spacing:10){Eyebrow(text:"POUR ALLER PLUS LOIN");Text("Les trois univers restent là. Le parcours te dit quand les utiliser.").font(.headline);HStack(spacing:7){WorldButton(title:"Prédire",icon:"bolt.fill",color:Color.konsensViolet){store.selectedTab = .play};WorldButton(title:"Décider",icon:"chart.line.uptrend.xyaxis",color:Color.konsensBlue){store.selectedTab = .invest};WorldButton(title:"Apprendre",icon:"book.fill",color:Color.konsensGold){store.selectedTab = .learn}}}.panel()} }
private struct WorldButton:View{let title:String;let icon:String;let color:Color;let action:()->Void;var body:some View{Button(action:action){VStack(spacing:6){Image(systemName:icon).foregroundStyle(color);Text(title).font(.system(size:8,weight:.bold))}.frame(maxWidth:.infinity).padding(.vertical,12).background(color.opacity(0.07),in:RoundedRectangle(cornerRadius:12))}.buttonStyle(.plain)}}
private struct ProfileShareCard:View{let score:KonsensScore?;let username:String;var body:some View{if let score{ShareLink(item:"Konsens · @\(username) · Score \(score.total_score)/100 · \(score.archetype) · Connaissance \(score.knowledge_score) · Risque \(score.risk_score) · Calibration \(score.calibration_score)"){Label("Partager ma carte de progression",systemImage:"square.and.arrow.up").font(.caption.bold()).frame(maxWidth:.infinity).padding(12).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:13))}.buttonStyle(.plain)}}}

private struct SponsoredCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var ad: SponsoredAd?
    @State private var sessionID = UUID().uuidString
    @State private var impressionTracked = false
    var body: some View { Group { if let ad { Button { Task { await track(ad,type:"click") };if let url=URL(string:ad.destinationURL){openURL(url)} } label:{HStack(spacing:13){Image(systemName:"sparkles.rectangle.stack.fill").font(.title3).foregroundStyle(Color.konsensGold).frame(width:44,height:44).background(Color.konsensGold.opacity(0.1),in:RoundedRectangle(cornerRadius:13));VStack(alignment:.leading,spacing:4){HStack(spacing:5){Text(ad.eyebrow.uppercased()).font(.system(size:7,weight:.bold)).tracking(1);Text("· \(ad.sponsorName)").font(.system(size:7,weight:.bold))}.foregroundStyle(Color.konsensGold);Text(ad.headline).font(.subheadline.bold()).multilineTextAlignment(.leading);if let body=ad.body{Text(body).font(.system(size:9)).foregroundStyle(Color.konsensMuted).lineLimit(2)}};Spacer();Image(systemName:"arrow.up.right").foregroundStyle(Color.konsensGold)}.padding(16).background(LinearGradient(colors:[Color.konsensGold.opacity(0.08),Color.konsensPanel],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(Color.konsensGold.opacity(0.14)))}.buttonStyle(.plain) } }.task{await load()} }
    private func load() async { struct Params:Encodable{let p_placement:String;let p_session_id:String};struct Row:Decodable{let campaign_id:UUID;let creative_id:UUID;let sponsor_name:String;let eyebrow:String;let headline:String;let body:String?;let cta_label:String;let destination_url:String;let placement:String};let params=Params(p_placement:"feed_native",p_session_id:sessionID);if let rows:[Row]=try? await store.supabase.rpc("get_active_ad",params:params).execute().value,let row=rows.first{let loaded=SponsoredAd(campaignID:row.campaign_id,id:row.creative_id,sponsorName:row.sponsor_name,eyebrow:row.eyebrow,headline:row.headline,body:row.body,ctaLabel:row.cta_label,destinationURL:row.destination_url,placement:row.placement);ad=loaded;if !impressionTracked{impressionTracked=true;await track(loaded,type:"impression")}} }
    private func track(_ ad:SponsoredAd,type:String) async { struct Params:Encodable{let p_campaign_id:UUID;let p_creative_id:UUID;let p_event_type:String;let p_placement:String;let p_session_id:String};_ = try? await store.supabase.rpc("track_ad_event",params:Params(p_campaign_id:ad.campaignID,p_creative_id:ad.id,p_event_type:type,p_placement:ad.placement,p_session_id:sessionID)).execute() }
}
