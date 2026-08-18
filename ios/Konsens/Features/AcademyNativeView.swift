import SwiftUI

struct AcademyNativeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: LearningLesson?

    private var progress: Double {
        guard !store.lessons.isEmpty else { return 0 }
        return Double(store.completedLessonIDs.count) / Double(store.lessons.count)
    }

    private var recommended: LearningLesson? {
        store.lessons.first { !store.completedLessonIDs.contains($0.id) } ?? store.lessons.last
    }

    private var earnedXP: Int {
        store.lessons.filter { store.completedLessonIDs.contains($0.id) }.reduce(0) { $0 + $1.xpReward }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                AcademyFunHero(progress: progress, streak: store.streak, xp: earnedXP, next: recommended?.title)

                AcademyProgressCard(
                    progress: progress,
                    completed: store.completedLessonIDs.count,
                    total: store.lessons.count,
                    recommended: recommended
                ) {
                    if let recommended { selected = recommended }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TON PARCOURS")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(1.2).foregroundStyle(Color.konsensGreen)
                        Text("Avance étape par étape").font(.title3.bold())
                    }
                    Spacer()
                    Text("~\(max(1, store.lessons.reduce(0) { $0 + $1.durationMinutes } / 60)) h")
                        .font(.caption.bold()).foregroundStyle(Color.konsensMuted)
                }
                .padding(.top, 4)

                AcademyPath(
                    lessons: store.lessons,
                    completedIDs: store.completedLessonIDs,
                    scores: store.learningScores,
                    recommendedID: recommended?.id
                ) { lesson in
                    selected = lesson
                }

                AcademyLearningThread()
            }
            .padding(.horizontal, 18).padding(.top, 106).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
        .sheet(item: $selected) { lesson in
            CourseSheet(lesson: lesson).environmentObject(store)
        }
    }
}

private struct AcademyFunHero: View {
    let progress: Double
    let streak: Int
    let xp: Int
    let next: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Capsule().fill(Color.konsensGreen).frame(width: 36, height: 4)
                    Text("UNIVERS APPRENDRE")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1).foregroundStyle(Color.konsensGreen)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.konsensGold)
                    Text("\(streak) j").font(.caption.bold())
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.konsensGold.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apprendre la finance\npeut être un jeu.")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .tracking(-1.2)
                    Text("Des mots simples, des exemples, des vidéos et des quiz. Chaque étape t’aide à mieux comprendre ce que tu peux gagner — et ce que tu peux perdre.")
                        .font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(Color.konsensGreen.opacity(0.12))
                    Circle().stroke(Color.konsensGreen.opacity(0.28), lineWidth: 2).padding(5)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color.konsensGreen, Color.konsensGold], startPoint: .top, endPoint: .bottom))
                }.frame(width: 104, height: 104)
            }

            HStack(spacing: 8) {
                academyMetric("\(Int((progress * 100).rounded()))%", "MAÎTRISÉ", Color.konsensGreen)
                academyMetric("\(xp)", "XP", Color.konsensViolet)
                academyMetric("10 min", "OBJECTIF/J", Color.konsensGold)
            }

            if let next {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.konsensGreen)
                    Text("Prochaine étape : \(next)").font(.caption.bold())
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.055, green: 0.105, blue: 0.074), Color(red: 0.035, green: 0.060, blue: 0.050)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26)
        )
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.konsensGreen.opacity(0.15)))
    }

    private func academyMetric(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit().bold()).foregroundStyle(tint)
            Text(label).font(.system(size: 6, weight: .black, design: .rounded)).foregroundStyle(Color.konsensMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AcademyProgressCard: View {
    let progress: Double
    let completed: Int
    let total: Int
    let recommended: LearningLesson?
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBJECTIF DU PARCOURS")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(1.1).foregroundStyle(Color.konsensGold)
                    Text("\(completed) / \(total) modules maîtrisés").font(.headline)
                }
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.title2.monospacedDigit().bold()).foregroundStyle(Color.konsensGreen)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.055))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.konsensGreen, Color.konsensGold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress)
                }
            }.frame(height: 9)

            if let recommended {
                Button(action: open) {
                    HStack(spacing: 11) {
                        ZStack {
                            Circle().fill(Color.konsensGreen.opacity(0.12))
                            Image(systemName: completed >= total ? "arrow.clockwise" : "play.fill")
                                .font(.caption.bold()).foregroundStyle(Color.konsensGreen)
                        }.frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completed >= total ? "RÉVISION CONSEILLÉE" : "CONTINUE ICI")
                                .font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted)
                            Text(recommended.title).font(.subheadline.bold()).foregroundStyle(Color.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.konsensGreen)
                    }
                    .padding(12)
                    .background(Color.konsensGreen.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
        }
        .padding(17)
        .background(Color(red: 0.045, green: 0.070, blue: 0.055), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.konsensGreen.opacity(0.13)))
    }
}

private struct AcademyPath: View {
    let lessons: [LearningLesson]
    let completedIDs: Set<UUID>
    let scores: [UUID: Int]
    let recommendedID: UUID?
    let open: (LearningLesson) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                let completed = completedIDs.contains(lesson.id)
                let current = lesson.id == recommendedID
                HStack {
                    if index.isMultiple(of: 2) { Spacer(minLength: 8) }
                    LessonPathNode(lesson: lesson, completed: completed, current: current, score: scores[lesson.id]) { open(lesson) }
                    if !index.isMultiple(of: 2) { Spacer(minLength: 8) }
                }
                if index < lessons.count - 1 {
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(completed ? Color.konsensGreen.opacity(0.70) : Color.white.opacity(0.08))
                            .frame(width: 5, height: 34)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? 18 : -18))
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct LessonPathNode: View {
    let lesson: LearningLesson
    let completed: Bool
    let current: Bool
    let score: Int?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(nodeColor.opacity(completed || current ? 0.20 : 0.08))
                        .overlay(Circle().stroke(nodeColor.opacity(completed || current ? 0.65 : 0.18), lineWidth: current ? 4 : 2))
                    if completed {
                        Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Color.konsensGreen)
                    } else if current {
                        Image(systemName: "play.fill").font(.title2.bold()).foregroundStyle(nodeColor)
                    } else {
                        Text("\(lesson.position)").font(.title3.monospacedDigit().bold()).foregroundStyle(nodeColor)
                    }
                }
                .frame(width: 68, height: 68)
                .shadow(color: current ? nodeColor.opacity(0.24) : .clear, radius: 18)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(lesson.level.uppercased()).font(.system(size: 6, weight: .black)).foregroundStyle(nodeColor)
                        Text("\(lesson.durationMinutes) MIN").font(.system(size: 6, weight: .bold)).foregroundStyle(Color.konsensMuted)
                        Text("+\(lesson.xpReward) XP").font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensViolet)
                    }
                    Text(lesson.title).font(.subheadline.bold()).multilineTextAlignment(.leading)
                    Text(lesson.summary).font(.system(size: 8)).foregroundStyle(Color.konsensMuted).lineLimit(2)
                    if let score {
                        HStack(spacing: 4) {
                            Image(systemName: score >= 70 ? "star.fill" : "arrow.clockwise")
                            Text("Score \(score)%")
                        }
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(score >= 70 ? Color.konsensGold : Color.konsensMuted)
                    } else if current {
                        Text("À TOI DE JOUER")
                            .font(.system(size: 7, weight: .black)).tracking(0.8).foregroundStyle(Color.konsensGreen)
                    }
                }
                .frame(maxWidth: 210, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(current ? 0.045 : 0.025), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .buttonStyle(.plain)
    }

    private var nodeColor: Color {
        if completed { return Color.konsensGreen }
        if current { return Color.konsensGold }
        switch lesson.position % 3 {
        case 0: return Color.konsensBlue
        case 1: return Color.konsensGreen
        default: return Color.konsensViolet
        }
    }
}

private struct AcademyLearningThread: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Color.konsensGreen)
                .frame(width: 38, height: 38)
                .background(Color.konsensGreen.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("LA LIGNE VERTE")
                    .font(.system(size: 7, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Color.konsensGreen)
                Text("Comprendre → décider → observer → apprendre.").font(.headline)
                Text("Ta progression ne récompense pas seulement le gain. Elle valorise aussi la compréhension du risque, la régularité et la qualité de tes décisions.")
                    .font(.caption).foregroundStyle(Color.konsensMuted).lineSpacing(3)
            }
        }
        .padding(16)
        .background(Color.konsensGreen.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensGreen.opacity(0.12)))
    }
}

private struct CourseSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let lesson: LearningLesson
    @State private var chapter = 0
    @State private var answers: [Int: Int] = [:]
    @State private var score: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            Capsule().fill(Color.konsensGreen).frame(width: 32, height: 4)
                            Text("MODULE \(String(format: "%02d", lesson.position)) · \(lesson.category.uppercased())")
                                .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGreen)
                        }
                        Text(lesson.title).font(.system(size: 32, weight: .black, design: .rounded))
                        Text("\(lesson.durationMinutes) min · \(lesson.level) · +\(lesson.xpReward) XP")
                            .font(.caption).foregroundStyle(Color.konsensMuted)
                        Text(lesson.concept).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("CE QUE TU VAS SAVOIR FAIRE")
                            .font(.system(size: 7, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Color.konsensGreen)
                        ForEach(lesson.objectives, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Color.konsensPositive)
                        }
                    }.academyPanel()

                    if !lesson.chapters.isEmpty {
                        Picker("Chapitre", selection: $chapter) {
                            ForEach(Array(lesson.chapters.enumerated()), id: \.offset) { index, _ in
                                Text("\(index + 1)").tag(index)
                            }
                        }.pickerStyle(.segmented)

                        let current = lesson.chapters[min(chapter, lesson.chapters.count - 1)]
                        VStack(alignment: .leading, spacing: 14) {
                            Text(current.title).font(.system(size: 25, weight: .bold, design: .rounded))
                            Text(current.body).font(.system(size: 17, design: .rounded)).lineSpacing(7)
                            if let example = current.example {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EXEMPLE CONCRET").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.konsensBlue)
                                    Text(example).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                                }
                                .padding(16)
                                .background(Color.konsensBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                            if let callout = current.callout {
                                Label(callout, systemImage: "lightbulb.fill")
                                    .font(.caption.bold()).foregroundStyle(Color.konsensGold)
                                    .padding(14)
                                    .background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }.academyPanel()
                    }

                    if let diagram = lesson.media.first(where: { $0.type == "diagram" }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("VOIR POUR COMPRENDRE")
                                .font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGreen)
                            Text(diagram.title).font(.headline)
                            NativeDiagram(kind: diagram.kind)
                        }.academyPanel()
                    }

                    let links = lesson.media.filter { $0.url != nil }
                    if !links.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VIDÉOS & SOURCES")
                                .font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGreen)
                            ForEach(links, id: \.title) { media in
                                Button {
                                    if let raw = media.url, let url = URL(string: raw) { openURL(url) }
                                } label: {
                                    HStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(media.type == "video" ? Color.konsensGold.opacity(0.08) : Color.konsensBlue.opacity(0.08))
                                            Image(systemName: media.type == "video" ? "play.fill" : "arrow.up.forward.square")
                                                .foregroundStyle(media.type == "video" ? Color.konsensGold : Color.konsensBlue)
                                        }.frame(width: 42, height: 42)
                                        VStack(alignment: .leading) {
                                            Text(media.title).font(.subheadline.bold())
                                            Text(media.source ?? "Ressource pédagogique").font(.caption2).foregroundStyle(Color.konsensMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(Color.konsensMuted)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 13))
                                }.buttonStyle(.plain)
                            }
                        }.academyPanel()
                    }

                    if chapter == max(lesson.chapters.count - 1, 0) && !lesson.quiz.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("QUIZ FINAL")
                                .font(.system(size: 7, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Color.konsensGreen)
                            Text("Montre ce que tu as compris.").font(.system(size: 25, weight: .black, design: .rounded))
                            ForEach(Array(lesson.quiz.enumerated()), id: \.offset) { index, quiz in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("\(index + 1). \(quiz.question)").font(.subheadline.bold())
                                    ForEach(Array(quiz.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                                        Button { answers[index] = choiceIndex } label: {
                                            HStack {
                                                Text(choice).font(.caption)
                                                Spacer()
                                                if answers[index] == choiceIndex {
                                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.konsensGreen)
                                                }
                                            }
                                            .padding(11)
                                            .background(answers[index] == choiceIndex ? Color.konsensGreen.opacity(0.09) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain)
                                    }
                                    if let answer = answers[index] {
                                        Text((answer == quiz.answer ? "Bonne réponse. " : "À revoir. ") + quiz.explanation)
                                            .font(.caption2)
                                            .foregroundStyle(answer == quiz.answer ? Color.konsensPositive : Color.konsensGold)
                                    }
                                }
                            }
                            Button("Valider le module") { Task { await validate() } }
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.03, green: 0.08, blue: 0.06))
                                .frame(maxWidth: .infinity).padding(14)
                                .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 15))
                                .disabled(answers.count < lesson.quiz.count)
                                .opacity(answers.count < lesson.quiz.count ? 0.35 : 1)
                            if let score {
                                Text("Score : \(score)% · \(score >= 70 ? "module maîtrisé" : "reprends les chapitres puis retente")")
                                    .font(.caption.bold())
                                    .foregroundStyle(score >= 70 ? Color.konsensPositive : Color.konsensGold)
                            }
                        }.academyPanel()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("À RETENIR")
                            .font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(Color.konsensGreen)
                        ForEach(lesson.takeaways, id: \.self) { takeaway in
                            Text("• \(takeaway)").font(.caption).foregroundStyle(Color.konsensMuted)
                        }
                    }.academyPanel()

                    if let risk = lesson.riskNote {
                        Label(risk, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.konsensGold).padding(16)
                            .background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .background(Color(red: 0.035, green: 0.060, blue: 0.046))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Color.konsensGreen)
                }
            }
        }
        .presentationBackground(Color(red: 0.035, green: 0.060, blue: 0.046))
        .onAppear { score = store.learningScores[lesson.id] }
    }

    private func validate() async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        let correct = lesson.quiz.enumerated().filter { answers[$0.offset] == $0.element.answer }.count
        let final = Int((Double(correct) / Double(max(lesson.quiz.count, 1)) * 100).rounded())
        struct Progress: Encodable {
            let user_id: UUID
            let module_id: UUID
            let completed_at: String
            let score: Int
        }
        try? await store.supabase.from("learning_progress").upsert(
            Progress(
                user_id: userID,
                module_id: lesson.id,
                completed_at: ISO8601DateFormatter().string(from: Date()),
                score: final
            ),
            onConflict: "user_id,module_id"
        ).execute()
        score = final
        await store.refreshFinance()
        if final >= 70 { store.showToast("Module validé · +\(lesson.xpReward) XP") }
    }
}

private struct NativeDiagram: View {
    let kind: String?

    var body: some View {
        switch kind {
        case "blockchain":
            HStack(spacing: 5) {
                node("TX"); arrow; node("BLOC"); arrow; node("CONFIRM."); arrow; node("EXPLORATEUR")
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
        case "rates-bonds":
            HStack {
                VStack { Text("TAUX"); Text("↑").font(.largeTitle).foregroundStyle(Color.konsensPositive) }
                Spacer()
                Rectangle().fill(Color.konsensMuted).frame(height: 2).rotationEffect(.degrees(-8))
                Spacer()
                VStack { Text("PRIX OBLIGATION"); Text("↓").font(.largeTitle).foregroundStyle(Color.konsensNegative) }
            }
            .font(.caption.bold()).padding(.vertical, 18)
        case "drawdown":
            VStack(alignment: .leading) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach([0.9, 0.78, 0.82, 0.43, 0.58, 0.72, 0.95], id: \.self) { value in
                        Capsule()
                            .fill(value < 0.6 ? Color.konsensNegative : Color.konsensPositive.opacity(0.7))
                            .frame(maxWidth: .infinity).frame(height: 120 * value)
                    }
                }
                Text("Une baisse profonde exige une récupération proportionnellement plus forte.")
                    .font(.caption2).foregroundStyle(Color.konsensMuted)
            }
        default:
            HStack(spacing: 16) {
                VStack { Text("ACHETEURS").font(.caption2); Text("99,90").bold(); Text("99,80") }
                Text("SPREAD").font(.caption.bold()).foregroundStyle(Color.konsensGold)
                VStack { Text("VENDEURS").font(.caption2); Text("100,10").bold(); Text("100,20") }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
        }
    }

    private func node(_ label: String) -> some View {
        Text(label).font(.system(size: 8, weight: .bold)).padding(9)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.konsensGreen)
    }
}

private extension View {
    func academyPanel() -> some View {
        self.padding(16)
            .background(Color(red: 0.052, green: 0.078, blue: 0.061), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.konsensGreen.opacity(0.10)))
    }
}