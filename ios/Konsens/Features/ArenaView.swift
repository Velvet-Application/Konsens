import SwiftUI

struct ArenaView: View {
    @EnvironmentObject private var store: AppStore
    @State private var score = JourneyScore()
    @State private var session = DailySession()
    @State private var confidence = 60.0
    @State private var stake = 25
    @State private var prediction = "yes"
    @State private var reason = "analyse"
    @State private var thesis = ""
    @State private var selectedStep: JourneyStep?
    @State private var replays: [ReplayScenario] = []
    @State private var selectedReplay: ReplayScenario?
    @State private var replayChoice: Int?
    @State private var leagues: [JourneyLeague] = []
    @State private var leagueName = ""
    @State private var joinCode = ""
    @State private var whatIfAmount = 100.0
    @State private var whatIfMonths = 12.0
    @State private var journal: [JournalRow] = []
    @State private var status = ""
    @State private var busy = false

    private var market: Market? { store.markets.first }
    private var asset: AssetQuote? { store.assets.first }
    private var lesson: LearningLesson? { store.lessons.first }
    private var progress: Int { [session.understand, session.predict, session.decide, session.learn].filter { $0 }.count }
    private var nextStep: JourneyStep? {
        if !session.understand { return .understand }
        if !session.predict { return .predict }
        if !session.decide { return .decide }
        if !session.learn { return .learn }
        return nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                hero
                dailyCard
                coachCard
                consensusCard
                replayCard
                whatIfCard
                journalCard
                leaguesCard
                profileCard
                if store.subscriptionTier == "free" { SponsorJourneyCard() }
                PremiumJourneyCard()
            }
            .padding(.horizontal, 18)
            .padding(.top, 92)
            .padding(.bottom, 110)
        }
        .refreshable { await loadJourney() }
        .task { await loadJourney() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "KONSENS · ENTRAÎNEMENT QUOTIDIEN")
            Text("Chaque jour, Konsens entraîne ta capacité à prendre de meilleures décisions avec l’argent.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("Comprendre → Prédire → Décider → Apprendre. Ton score récompense surtout la qualité du raisonnement, du risque et de la régularité.")
                .font(.subheadline).foregroundStyle(Color.konsensMuted)
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 8)
                    Circle().trim(from: 0, to: max(0.03, score.total / 100)).stroke(AngularGradient(colors: [Color.konsensGreen, Color.konsensBlue, Color.konsensViolet], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) { Text("\(Int(score.total.rounded()))").font(.title.bold().monospacedDigit()); Text("/100").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }
                }.frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "KONSENS SCORE")
                    Text(score.archetype).font(.headline)
                    Text("\(score.streak) j de régularité · \(session.xp) XP aujourd’hui").font(.caption).foregroundStyle(Color.konsensMuted)
                }
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(Color.konsensGreen).frame(width: geo.size.width * CGFloat(progress) / 4)
                    }
                }.frame(height: 6)
                Text("\(progress)/4").font(.caption.monospacedDigit().bold())
            }
        }
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { VStack(alignment: .leading, spacing: 3) { Eyebrow(text: "TON KONSENS DU JOUR · 4 À 7 MIN"); Text("Fais une chose bien à la fois.").font(.title3.bold()) }; Spacer(); Text(nextStep?.label.uppercased() ?? "TERMINÉ").font(.system(size: 7, weight: .black)).tracking(1).foregroundStyle(Color.konsensGreen) }
            ForEach(JourneyStep.allCases) { step in
                Button { selectedStep = selectedStep == step ? nil : step } label: {
                    HStack(spacing: 12) {
                        Text(isDone(step) ? "✓" : "0\(step.rawValue)").font(.system(size: 9, weight: .black)).foregroundStyle(isDone(step) ? Color.konsensPositive : (nextStep == step ? Color.konsensGreen : Color.konsensMuted)).frame(width: 32, height: 32).background((isDone(step) ? Color.konsensPositive : Color.konsensGreen).opacity(isDone(step) || nextStep == step ? 0.10 : 0.03), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) { Text(step.label).font(.subheadline.bold()); Text(stepDetail(step)).font(.system(size: 9)).foregroundStyle(Color.konsensMuted).lineLimit(2) }
                        Spacer(); Image(systemName: selectedStep == step ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Color.konsensMuted)
                    }.padding(12).background(nextStep == step ? Color.konsensGreen.opacity(0.045) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain)
                if selectedStep == step { actionView(step).transition(.opacity.combined(with: .move(edge: .top))) }
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(Color.konsensBlue).padding(10).background(Color.konsensBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)) }
        }.panel()
    }

    @ViewBuilder private func actionView(_ step: JourneyStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if step == .understand {
                Text(market?.category.uppercased() ?? "SIGNAL DU JOUR").font(.caption2.bold()).foregroundStyle(Color.konsensGreen)
                Text(market?.sourceSummary ?? "Avant d’agir, sépare le fait observable de ton interprétation.").font(.subheadline).foregroundStyle(Color.konsensMuted)
                Text("Question : quelle information pourrait te faire changer d’avis ?").font(.caption.bold())
                actionButton("J’ai compris · +10 XP") { await complete(.understand, xp: 10) }
            } else if step == .predict {
                Text(market?.question ?? "Aucun marché disponible").font(.headline)
                HStack(spacing: 8) { choiceButton("OUI", active: prediction == "yes", tint: Color.konsensPositive) { prediction = "yes" }; choiceButton("NON", active: prediction == "no", tint: Color.konsensNegative) { prediction = "no" } }
                confidenceSlider
                decisionFields
                stakeSelector
                actionButton(busy ? "Enregistrement…" : "Confirmer \(prediction.uppercased()) · \(stake) K", disabled: busy || market == nil || store.credits < stake) { await executePrediction() }
            } else if step == .decide {
                Text(asset.map { "\($0.name) · \($0.symbol)" } ?? "Actif du jour").font(.headline)
                Text("Dimensionne la position avant de chercher le rendement. La taille de la décision fait partie de la décision.").font(.caption).foregroundStyle(Color.konsensMuted)
                confidenceSlider
                decisionFields
                stakeSelector
                actionButton(busy ? "Simulation…" : "Investir \(stake) K en simulation", disabled: busy || asset == nil || store.credits < stake) { await executeInvestment() }
            } else {
                Text(lesson?.title ?? "Diversification").font(.headline)
                Text(lesson?.summary ?? "Répartir les sources de risque ne garantit jamais l’absence de perte.").font(.caption).foregroundStyle(Color.konsensMuted)
                Text("Une diversification correcte réduit certains risques sans les supprimer.").font(.subheadline.bold()).padding(11).background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                actionButton("Valider l’apprentissage · +15 XP") { await complete(.learn, xp: 15) }
            }
        }.padding(12).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))
    }

    private var confidenceSlider: some View { VStack(alignment: .leading, spacing: 5) { HStack { Text("Confiance").font(.caption); Spacer(); Text("\(Int(confidence))%").font(.caption.monospacedDigit().bold()) }; Slider(value: $confidence, in: 40...95, step: 5).tint(Color.konsensViolet) } }
    private var decisionFields: some View { VStack(spacing: 8) { Picker("Pourquoi ?", selection: $reason) { Text("Analyse").tag("analyse"); Text("Actualité").tag("actualite"); Text("Intuition").tag("intuition"); Text("Stratégie").tag("strategie") }.pickerStyle(.segmented); TextField("Ta thèse en une phrase…", text: $thesis, axis: .vertical).textFieldStyle(.plain).padding(11).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11)) } }
    private var stakeSelector: some View { HStack(spacing: 6) { ForEach([10, 25, 50, 100], id: \.self) { value in Button("\(value) K") { stake = value }.font(.caption.bold()).buttonStyle(.plain).padding(.horizontal, 9).padding(.vertical, 7).background(stake == value ? Color.konsensGreen.opacity(0.12) : Color.white.opacity(0.035), in: Capsule()).foregroundStyle(stake == value ? Color.konsensGreen : Color.konsensMuted) } } }

    private var coachCard: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.konsensViolet).frame(width: 44, height: 44).background(Color.konsensViolet.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 6) { Eyebrow(text: "KONSENS COACH"); Text(coachTitle).font(.headline); Text(coachBody).font(.caption).foregroundStyle(Color.konsensMuted); HStack(spacing: 5) { miniMetric("Prévision", score.prediction); miniMetric("Risque", score.risk); miniMetric("Savoir", score.knowledge) } }
        }.panel()
    }

    private var consensusCard: some View {
        VStack(alignment: .leading, spacing: 12) { Eyebrow(text: "LE CONSENSUS"); Text("Toi contre la foule, le marché et l’IA.").font(.headline); if let market { HStack(spacing: 7) { consensusMetric("COMMUNAUTÉ", Double(market.yesProbability)); consensusMetric("IA", (market.aiConfidence ?? Double(market.yesProbability)/100) * 100); consensusMetric("TOI", confidence) }; Text(market.question).font(.caption.bold()); Text(market.aiRationale ?? "L’écart entre les convictions est un signal à questionner, pas une preuve.").font(.caption).foregroundStyle(Color.konsensMuted) }; Button { store.selectedTab = .play } label: { Label("Explorer les marchés", systemImage: "arrow.right").font(.caption.bold()) }.buttonStyle(.plain).foregroundStyle(Color.konsensViolet) }.panel()
    }

    private var replayCard: some View {
        VStack(alignment: .leading, spacing: 11) { Eyebrow(text: "REPLAY DU RÉEL"); Text("Décide avant de connaître la suite.").font(.headline); ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 7) { ForEach(replays) { replay in Button { selectedReplay = replay; replayChoice = nil } label: { VStack(alignment: .leading, spacing: 3) { Text(replay.era).font(.caption2.bold()).foregroundStyle(Color.konsensViolet); Text(replay.title).font(.caption.bold()).lineLimit(2) }.frame(width: 150, alignment: .leading).padding(10).background(selectedReplay?.id == replay.id ? Color.konsensViolet.opacity(0.10) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain) } } }; if let replay = selectedReplay { Text(replay.setup).font(.caption).foregroundStyle(Color.konsensMuted); ForEach(Array(replay.choices.enumerated()), id: \.offset) { index, choice in Button { replayChoice = index } label: { HStack { Text(choice.label).font(.caption.bold()); Spacer(); if replayChoice == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.konsensGreen) } }.padding(10).background(replayChoice == index ? Color.konsensGreen.opacity(0.07) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)) }.buttonStyle(.plain) }; if let replayChoice { VStack(alignment: .leading, spacing: 5) { Text("Ce qui s’est passé").font(.caption.bold()).foregroundStyle(Color.konsensGreen); Text(replay.reveal).font(.caption).foregroundStyle(Color.konsensMuted); Text(replay.lesson).font(.system(size: 8)).foregroundStyle(Color.konsensViolet); Button("Enregistrer mon Replay") { Task { await saveReplay(replay, choice: replayChoice) } }.font(.caption.bold()).buttonStyle(.plain).foregroundStyle(Color.konsensGreen) }.padding(11).background(Color.konsensGreen.opacity(0.045), in: RoundedRectangle(cornerRadius: 12)) } } }.panel()
    }

    private var whatIfCard: some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "ET SI…"); Text("Teste une stratégie sans risquer un euro.").font(.headline); HStack { Text("Montant mensuel").font(.caption); Spacer(); Text("\(Int(whatIfAmount)) K").font(.caption.bold()) }; Slider(value: $whatIfAmount, in: 25...500, step: 25).tint(Color.konsensBlue); HStack { Text("Durée").font(.caption); Spacer(); Text("\(Int(whatIfMonths)) mois").font(.caption.bold()) }; Slider(value: $whatIfMonths, in: 3...60, step: 3).tint(Color.konsensBlue); let invested = whatIfAmount * whatIfMonths; let estimated = invested * pow(1.06, whatIfMonths/12); VStack(alignment: .leading, spacing: 3) { Text("Hypothèse pédagogique +6%/an").font(.caption2).foregroundStyle(Color.konsensMuted); Text("≈ \(Int(estimated.rounded())) K").font(.title2.monospacedDigit().bold()); Text("pour \(Int(invested)) K versés · ce n’est pas une prévision").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }.padding(12).background(Color.konsensBlue.opacity(0.05), in: RoundedRectangle(cornerRadius: 13)); Button("Enregistrer ce scénario") { Task { await saveWhatIf(invested: invested, estimated: estimated) } }.font(.caption.bold()).buttonStyle(.plain).foregroundStyle(Color.konsensBlue) }.panel()
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "JOURNAL DES DÉCISIONS"); Text("Ce que tu pensais compte autant que le résultat.").font(.headline); if journal.isEmpty { Text("Ton journal se remplira après tes prochaines décisions.").font(.caption).foregroundStyle(Color.konsensMuted) } else { ForEach(journal.prefix(5)) { row in VStack(alignment: .leading, spacing: 3) { Text(row.type == "bet" ? "PRÉDICTION" : "INVESTISSEMENT").font(.system(size: 7, weight: .black)).foregroundStyle(Color.konsensGreen); Text(row.thesis ?? row.reason ?? "Décision enregistrée").font(.caption.bold()).lineLimit(2); Text("Confiance \(row.confidence.map(String.init) ?? "—")% · \(Int(row.credits)) K").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }.padding(9).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)) } } }.panel()
    }

    private var leaguesCard: some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "LIGUES KONSENS"); Text("On compare la qualité des décisions, pas seulement la richesse.").font(.headline); HStack { TextField("Nom de la ligue", text: $leagueName).textFieldStyle(.plain).padding(9).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)); Button("Créer") { Task { await createLeague() } }.font(.caption.bold()).buttonStyle(.bordered).tint(Color.konsensGreen) }; HStack { TextField("Code d’invitation", text: $joinCode).textFieldStyle(.plain).textInputAutocapitalization(.characters).padding(9).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)); Button("Rejoindre") { Task { await joinLeague() } }.font(.caption.bold()).buttonStyle(.bordered).tint(Color.konsensViolet) }; ForEach(leagues) { league in HStack { VStack(alignment: .leading) { Text(league.name).font(.caption.bold()); Text("\(league.members) membre(s) · Score Konsens").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }; Spacer(); Text(league.code).font(.caption.monospaced().bold()).foregroundStyle(Color.konsensGreen) }.padding(9).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)) } }.panel()
    }

    private var profileCard: some View {
        HStack(spacing: 14) { Image("KonsensLogo").resizable().scaledToFit().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 3) { Eyebrow(text: "TA CARTE KONSENS"); Text(score.archetype).font(.headline); Text("Score \(Int(score.total.rounded())) · Prévision \(Int(score.prediction.rounded())) · Risque \(Int(score.risk.rounded())) · Savoir \(Int(score.knowledge.rounded()))").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }; Spacer(); ShareLink(item: "Konsens Score \(Int(score.total.rounded()))/100 · \(score.archetype) · Prévision \(Int(score.prediction.rounded())) · Risque \(Int(score.risk.rounded())) · Connaissance \(Int(score.knowledge.rounded()))") { Image(systemName: "square.and.arrow.up").foregroundStyle(Color.konsensGreen) } }.panel()
    }

    private func actionButton(_ title: String, disabled: Bool = false, action: @escaping () async -> Void) -> some View { Button { Task { await action() } } label: { Text(title).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(11) }.buttonStyle(.plain).foregroundStyle(Color.konsensBackground).background(Color.konsensGreen.opacity(disabled ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 13)).disabled(disabled) }
    private func choiceButton(_ title: String, active: Bool, tint: Color, action: @escaping () -> Void) -> some View { Button(action: action) { Text(title).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(10).background(active ? tint.opacity(0.13) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? tint.opacity(0.22) : Color.white.opacity(0.04))).foregroundStyle(active ? tint : Color.konsensMuted) }.buttonStyle(.plain) }
    private func miniMetric(_ title: String, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 2) { Text(title.uppercased()).font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted); Text("\(Int(value.rounded()))").font(.caption.monospacedDigit().bold()) }.padding(8).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10)) }
    private func consensusMetric(_ title: String, _ value: Double) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted); Text("\(Int(value.rounded()))%").font(.title3.monospacedDigit().bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)) }

    private func isDone(_ step: JourneyStep) -> Bool { switch step { case .understand: session.understand; case .predict: session.predict; case .decide: session.decide; case .learn: session.learn } }
    private func stepDetail(_ step: JourneyStep) -> String { switch step { case .understand: market?.sourceSummary ?? "Lire le signal avant d’agir"; case .predict: market?.question ?? "Estimer une probabilité"; case .decide: asset.map { "\($0.symbol) · décision dimensionnée" } ?? "Investir avec une règle de risque"; case .learn: lesson?.title ?? "Transformer l’erreur en connaissance" } }
    private var coachTitle: String { if score.calibration < 55 { return "Calibre mieux ta confiance." }; if score.risk < 55 { return "Dimensionne mieux ton risque." }; if score.knowledge < 55 { return "Renforce la connaissance avant d’agir." }; return "Ta méthode devient plus régulière." }
    private var coachBody: String { if score.calibration < 55 { return "Quand tu annonces 80% de confiance, le résultat devrait confirmer cette confiance environ 8 fois sur 10. Note ta conviction avant chaque prédiction." }; if score.risk < 55 { return "Une bonne idée peut devenir une mauvaise décision si la position est trop grande. Garde les nouvelles décisions petites et répétables." }; return "Konsens ne récompense pas seulement les gains : ton score progresse avec la discipline, la connaissance et la qualité du raisonnement." }

    private func loadJourney() async {
        await store.refreshFinance()
        struct Empty: Encodable {}
        struct ScoreRow: Decodable { let total_score: Double; let prediction_score: Double; let risk_score: Double; let knowledge_score: Double; let discipline_score: Double; let diversification_score: Double; let calibration_score: Double; let archetype: String; let streak_days: Int; let best_streak: Int }
        if let rows: [ScoreRow] = try? await store.supabase.rpc("get_my_konsens_score", params: Empty()).execute().value, let row = rows.first { score = JourneyScore(total: row.total_score, prediction: row.prediction_score, risk: row.risk_score, knowledge: row.knowledge_score, discipline: row.discipline_score, diversification: row.diversification_score, calibration: row.calibration_score, archetype: row.archetype, streak: row.streak_days) }
        struct SessionRow: Decodable { let understand_completed_at: String?; let predict_completed_at: String?; let decide_completed_at: String?; let learn_completed_at: String?; let completed_at: String?; let xp_earned: Int }
        if let row: SessionRow = try? await store.supabase.rpc("ensure_daily_session", params: Empty()).single().execute().value { session = DailySession(understand: row.understand_completed_at != nil, predict: row.predict_completed_at != nil, decide: row.decide_completed_at != nil, learn: row.learn_completed_at != nil, complete: row.completed_at != nil, xp: row.xp_earned) }
        struct ReplayRow: Decodable { let id: UUID; let title: String; let era: String; let setup: String; let choices: [ReplayChoice]; let reveal_text: String; let lesson: String }
        let replayRows: [ReplayRow] = (try? await store.supabase.from("replay_scenarios").select("id,title,era,setup,choices,reveal_text,lesson").eq("active", value: true).order("position").limit(8).execute().value) ?? []
        replays = replayRows.map { ReplayScenario(id: $0.id, title: $0.title, era: $0.era, setup: $0.setup, choices: $0.choices, reveal: $0.reveal_text, lesson: $0.lesson) }
        struct LeagueRow: Decodable { let id: UUID; let name: String; let join_code: String; let member_count: Int }
        let leagueRows: [LeagueRow] = (try? await store.supabase.rpc("get_my_leagues", params: Empty()).execute().value) ?? []
        leagues = leagueRows.map { JourneyLeague(id: $0.id, name: $0.name, code: $0.join_code, members: $0.member_count) }
        struct JournalRaw: Decodable { let id: UUID; let decision_type: String; let reason_code: String?; let confidence: Int?; let thesis: String?; let credits: Double }
        let journalRows: [JournalRaw] = (try? await store.supabase.from("decision_journal").select("id,decision_type,reason_code,confidence,thesis,credits").order("decision_at", ascending: false).limit(8).execute().value) ?? []
        journal = journalRows.map { JournalRow(id: $0.id, type: $0.decision_type, reason: $0.reason_code, confidence: $0.confidence, thesis: $0.thesis, credits: $0.credits) }
        if selectedReplay == nil { selectedReplay = replays.first }
    }

    private func complete(_ step: JourneyStep, xp: Int) async {
        struct Params: Encodable { let p_step: String; let p_xp: Int }
        _ = try? await store.supabase.rpc("complete_daily_step", params: Params(p_step: step.key, p_xp: xp)).execute()
        selectedStep = nil
        await loadJourney()
    }

    private func executePrediction() async {
        guard let market, let userID = store.supabase.auth.currentUser?.id else { return }
        busy = true; defer { busy = false }
        struct Order: Encodable { let user_id: UUID; let asset_id: UUID?; let market_id: UUID?; let side: String; let outcome: String?; let credits: Int; let idempotency_key: UUID }
        struct Result: Decodable { let id: UUID; let status: String; let rejection_reason: String? }
        do {
            let result: Result = try await store.supabase.from("trade_orders").insert(Order(user_id: userID, asset_id: nil, market_id: market.id, side: "buy", outcome: prediction, credits: stake, idempotency_key: UUID())).select("id,status,rejection_reason").single().execute().value
            guard result.status == "executed" else { status = result.rejection_reason ?? "Ordre refusé"; return }
            struct Note: Encodable { let p_trade_order_id: UUID; let p_reason: String; let p_confidence: Int; let p_thesis: String; let p_expectation: String; let p_emotion: String }
            _ = try? await store.supabase.rpc("save_decision_note", params: Note(p_trade_order_id: result.id, p_reason: reason, p_confidence: Int(confidence), p_thesis: thesis.isEmpty ? "Je formalise mon hypothèse avant de connaître le résultat." : thesis, p_expectation: "Je pense que \(prediction.uppercased()) est le scénario le plus probable.", p_emotion: "neutre")).execute()
            await complete(.predict, xp: 15); status = "Prédiction enregistrée dans ton journal."
        } catch { status = "Impossible d’enregistrer la prédiction." }
    }

    private func executeInvestment() async {
        guard let asset, let userID = store.supabase.auth.currentUser?.id else { return }
        busy = true; defer { busy = false }
        _ = await store.liveQuote(for: asset, range: "5d")
        struct Order: Encodable { let user_id: UUID; let asset_id: UUID?; let market_id: UUID?; let side: String; let outcome: String?; let credits: Int; let idempotency_key: UUID }
        struct Result: Decodable { let id: UUID; let status: String; let rejection_reason: String? }
        do {
            let result: Result = try await store.supabase.from("trade_orders").insert(Order(user_id: userID, asset_id: asset.id, market_id: nil, side: "buy", outcome: nil, credits: stake, idempotency_key: UUID())).select("id,status,rejection_reason").single().execute().value
            guard result.status == "executed" else { status = result.rejection_reason ?? "Ordre refusé"; return }
            struct Note: Encodable { let p_trade_order_id: UUID; let p_reason: String; let p_confidence: Int; let p_thesis: String; let p_expectation: String; let p_emotion: String }
            _ = try? await store.supabase.rpc("save_decision_note", params: Note(p_trade_order_id: result.id, p_reason: reason, p_confidence: Int(confidence), p_thesis: thesis.isEmpty ? "Je teste une position petite et mesurée." : thesis, p_expectation: "Je veux observer le résultat sans surdimensionner le risque.", p_emotion: "neutre")).execute()
            await complete(.decide, xp: 15); status = "Décision enregistrée dans ton journal."
        } catch { status = "Impossible d’exécuter la simulation." }
    }

    private func saveReplay(_ replay: ReplayScenario, choice: Int) async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Row: Encodable { let user_id: UUID; let scenario_id: UUID; let selected_choice: Int; let confidence: Int }
        try? await store.supabase.from("replay_sessions").insert(Row(user_id: userID, scenario_id: replay.id, selected_choice: choice, confidence: Int(confidence))).execute()
        status = "Replay enregistré."
    }
    private func saveWhatIf(invested: Double, estimated: Double) async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        struct Row: Encodable { let user_id: UUID; let title: String; let scenario_type: String; let parameters: [String: Double]; let result_summary: [String: Double] }
        try? await store.supabase.from("scenario_simulations").insert(Row(user_id: userID, title: "DCA \(Int(whatIfAmount)) K / mois", scenario_type: "dca", parameters: ["monthly": whatIfAmount, "months": whatIfMonths, "assumption": 0.06], result_summary: ["invested": invested, "estimated": estimated])).execute()
        status = "Scénario enregistré."
    }
    private func createLeague() async { guard !leagueName.trimmingCharacters(in: .whitespaces).isEmpty else { return }; struct Params: Encodable { let p_name: String; let p_dimension: String }; _ = try? await store.supabase.rpc("create_league", params: Params(p_name: leagueName, p_dimension: "score")).execute(); leagueName = ""; await loadJourney() }
    private func joinLeague() async { guard !joinCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }; struct Params: Encodable { let p_code: String }; do { _ = try await store.supabase.rpc("join_league", params: Params(p_code: joinCode)).execute(); joinCode = ""; await loadJourney() } catch { status = "Code de ligue introuvable." } }
}

private enum JourneyStep: Int, CaseIterable, Identifiable { case understand = 1, predict, decide, learn; var id: Int { rawValue }; var label: String { switch self { case .understand: "Comprendre"; case .predict: "Prédire"; case .decide: "Décider"; case .learn: "Apprendre" } }; var key: String { switch self { case .understand: "understand"; case .predict: "predict"; case .decide: "decide"; case .learn: "learn" } } }
private struct JourneyScore { var total = 50.0; var prediction = 50.0; var risk = 50.0; var knowledge = 50.0; var discipline = 50.0; var diversification = 50.0; var calibration = 50.0; var archetype = "Explorateur"; var streak = 0 }
private struct DailySession { var understand = false; var predict = false; var decide = false; var learn = false; var complete = false; var xp = 0 }
private struct ReplayChoice: Codable, Hashable { let label: String; let impact: String }
private struct ReplayScenario: Identifiable { let id: UUID; let title: String; let era: String; let setup: String; let choices: [ReplayChoice]; let reveal: String; let lesson: String }
private struct JourneyLeague: Identifiable { let id: UUID; let name: String; let code: String; let members: Int }
private struct JournalRow: Identifiable { let id: UUID; let type: String; let reason: String?; let confidence: Int?; let thesis: String?; let credits: Double }

private struct SponsorJourneyCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var ad: SponsoredAd?
    @State private var sessionID = UUID().uuidString
    @State private var tracked = false
    var body: some View { Group { if let ad { Button { Task { await track(ad, type: "click") }; if let url = URL(string: ad.destinationURL) { openURL(url) } } label: { HStack(spacing: 12) { Image(systemName: "sparkles.rectangle.stack.fill").foregroundStyle(Color.konsensGold).frame(width: 42, height: 42).background(Color.konsensGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 3) { Eyebrow(text: "SPONSORISÉ · \(ad.sponsorName.uppercased())"); Text(ad.headline).font(.subheadline.bold()); if let body = ad.body { Text(body).font(.system(size: 8)).foregroundStyle(Color.konsensMuted).lineLimit(2) } }; Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Color.konsensGold) }.panel() }.buttonStyle(.plain) } }.task { await load() } }
    private func load() async { struct Params: Encodable { let p_placement: String; let p_session_id: String }; struct Row: Decodable { let campaign_id: UUID; let creative_id: UUID; let sponsor_name: String; let eyebrow: String; let headline: String; let body: String?; let cta_label: String; let destination_url: String; let placement: String }; if let rows: [Row] = try? await store.supabase.rpc("get_active_ad", params: Params(p_placement: "feed_native", p_session_id: sessionID)).execute().value, let row = rows.first { let loaded = SponsoredAd(campaignID: row.campaign_id, id: row.creative_id, sponsorName: row.sponsor_name, eyebrow: row.eyebrow, headline: row.headline, body: row.body, ctaLabel: row.cta_label, destinationURL: row.destination_url, placement: row.placement); ad = loaded; if !tracked { tracked = true; await track(loaded, type: "impression") } } }
    private func track(_ ad: SponsoredAd, type: String) async { struct Params: Encodable { let p_campaign_id: UUID; let p_creative_id: UUID; let p_event_type: String; let p_placement: String; let p_session_id: String }; _ = try? await store.supabase.rpc("track_ad_event", params: Params(p_campaign_id: ad.campaignID, p_creative_id: ad.id, p_event_type: type, p_placement: ad.placement, p_session_id: sessionID)).execute() }
}
private struct PremiumJourneyCard: View { @EnvironmentObject private var store: AppStore; var body: some View { HStack(spacing: 13) { Image(systemName: "crown.fill").foregroundStyle(Color.konsensViolet); VStack(alignment: .leading, spacing: 3) { Eyebrow(text: "KONSENS PREMIUM"); Text(store.subscriptionTier == "premium" ? "Ton laboratoire avancé est actif" : "Coach, historique et alertes avancées").font(.headline); Text("Sans pub · analyses personnelles · Whale Watch · scénarios · alertes intelligentes").font(.system(size: 8)).foregroundStyle(Color.konsensMuted) }; Spacer() }.padding(18).background(LinearGradient(colors: [Color.konsensViolet.opacity(0.12), Color.konsensPanel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensViolet.opacity(0.18))) } }
