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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "KONSENS ACADEMY · PARCOURS GUIDÉ")
                    Text("Comprendre avant\nde risquer.")
                        .font(.system(size: 38, weight: .semibold, design: .serif))
                        .tracking(-1.1)
                    Text("Des mots simples, des exemples concrets, des schémas, des vidéos et des quiz. Tu avances à ton rythme et ta progression reste synchronisée.")
                        .font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(3)
                }

                AcademyProgressCard(progress: progress, completed: store.completedLessonIDs.count, total: store.lessons.count, recommended: recommended) {
                    if let recommended { selected = recommended }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CURSUS").font(.system(size: 7, weight: .black)).tracking(1.2).foregroundStyle(Color.konsensGold)
                        Text("Ton chemin de compréhension").font(.title3).fontWeight(.semibold)
                    }
                    Spacer()
                    Text("\(store.lessons.reduce(0) { $0 + $1.durationMinutes } / 60) h env.").font(.caption2).foregroundStyle(Color.konsensMuted)
                }.padding(.top, 4)

                ForEach(store.lessons) { lesson in
                    let completed = store.completedLessonIDs.contains(lesson.id)
                    Button { selected = lesson } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(completed ? Color.konsensPositive.opacity(0.12) : Color.konsensGold.opacity(0.07))
                                if completed {
                                    Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(Color.konsensPositive)
                                } else {
                                    Text(String(format: "%02d", lesson.position))
                                        .font(.headline.monospacedDigit()).foregroundStyle(Color.konsensGold.opacity(0.75))
                                }
                            }.frame(width: 42, height: 42)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    Text(lesson.level.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensGold)
                                    Text("\(lesson.durationMinutes) MIN").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                                    Text("+\(lesson.xpReward) XP").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensViolet)
                                    if let score = store.learningScores[lesson.id] {
                                        Text("\(score)%").font(.system(size: 7, weight: .black)).foregroundStyle(score >= 70 ? Color.konsensPositive : Color.konsensGold)
                                    }
                                }
                                Text(lesson.title).font(.system(size: 17, weight: .semibold, design: .serif))
                                Text(lesson.summary).font(.caption).foregroundStyle(Color.konsensMuted).lineLimit(3)
                                HStack(spacing: 8) {
                                    Label("\(lesson.chapters.count) chapitres", systemImage: "text.book.closed")
                                    Label("\(lesson.media.filter { $0.url != nil }.count) ressources", systemImage: "play.rectangle")
                                    Label("\(lesson.quiz.count) quiz", systemImage: "checkmark.circle")
                                }.font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.konsensGold.opacity(0.65))
                        }
                        .padding(16)
                        .background(Color(red: 0.055, green: 0.075, blue: 0.062), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.konsensGold.opacity(completed ? 0.15 : 0.09)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .refreshable { await store.refreshFinance() }
        .sheet(item: $selected) { lesson in
            CourseSheet(lesson: lesson).environmentObject(store)
        }
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
                    Text("TA PROGRESSION").font(.system(size: 7, weight: .black)).tracking(1.1).foregroundStyle(Color.konsensGold)
                    Text("\(completed) / \(total) modules maîtrisés").font(.headline)
                }
                Spacer()
                Text("\(Int((progress * 100).rounded()))%").font(.title2.monospacedDigit().bold()).foregroundStyle(Color.konsensGold)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.055))
                    Capsule().fill(LinearGradient(colors: [Color.konsensGold.opacity(0.65), Color.konsensPositive.opacity(0.8)], startPoint: .leading, endPoint: .trailing)).frame(width: proxy.size.width * progress)
                }
            }.frame(height: 7)
            if let recommended {
                Button(action: open) {
                    HStack(spacing: 10) {
                        Image(systemName: "bookmark.fill").foregroundStyle(Color.konsensGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completed >= total ? "À REVOIR" : "PROCHAIN MODULE").font(.system(size: 6, weight: .black)).foregroundStyle(Color.konsensMuted)
                            Text(recommended.title).font(.subheadline.bold()).foregroundStyle(Color.white)
                        }
                        Spacer(); Image(systemName: "arrow.right").foregroundStyle(Color.konsensGold)
                    }.padding(12).background(Color.konsensGold.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding(17)
        .background(LinearGradient(colors: [Color.konsensGold.opacity(0.075), Color(red: 0.045, green: 0.062, blue: 0.052)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.konsensGold.opacity(0.15)))
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
                        Eyebrow(text: "MODULE \(String(format: "%02d", lesson.position)) · \(lesson.category.uppercased())")
                        Text(lesson.title).font(.system(size: 32, weight: .semibold, design: .serif))
                        Text("\(lesson.durationMinutes) min · \(lesson.level) · +\(lesson.xpReward) XP")
                            .font(.caption).foregroundStyle(Color.konsensMuted)
                        Text(lesson.concept).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "CE QUE TU VAS SAVOIR FAIRE")
                        ForEach(lesson.objectives, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.konsensPositive)
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
                            Text(current.title).font(.system(size: 25, weight: .semibold, design: .serif))
                            Text(current.body).font(.system(size: 17, design: .serif)).lineSpacing(7)
                            if let example = current.example {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EXEMPLE CONCRET").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.konsensBlue)
                                    Text(example).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                                }.padding(16).background(Color.konsensBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                            if let callout = current.callout {
                                Label(callout, systemImage: "lightbulb.fill")
                                    .font(.caption.bold()).foregroundStyle(Color.konsensGold)
                                    .padding(14).background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }.academyPanel()
                    }

                    if let diagram = lesson.media.first(where: { $0.type == "diagram" }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "VOIR POUR COMPRENDRE")
                            Text(diagram.title).font(.headline)
                            NativeDiagram(kind: diagram.kind)
                        }.academyPanel()
                    }

                    let links = lesson.media.filter { $0.url != nil }
                    if !links.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "VIDÉOS & SOURCES")
                            ForEach(links, id: \.title) { media in
                                Button {
                                    if let raw = media.url, let url = URL(string: raw) { openURL(url) }
                                } label: {
                                    HStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10).fill(media.type == "video" ? Color.konsensGold.opacity(0.08) : Color.konsensBlue.opacity(0.08))
                                            Image(systemName: media.type == "video" ? "play.fill" : "arrow.up.forward.square").foregroundStyle(media.type == "video" ? Color.konsensGold : Color.konsensBlue)
                                        }.frame(width: 42, height: 42)
                                        VStack(alignment: .leading) {
                                            Text(media.title).font(.subheadline.bold())
                                            Text(media.source ?? "Ressource pédagogique").font(.caption2).foregroundStyle(Color.konsensMuted)
                                        }
                                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.konsensMuted)
                                    }.padding(12).background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 13))
                                }.buttonStyle(.plain)
                            }
                        }.academyPanel()
                    }

                    if chapter == max(lesson.chapters.count - 1, 0) && !lesson.quiz.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "VALIDATION")
                            Text("Teste ta compréhension.").font(.system(size: 25, weight: .semibold, design: .serif))
                            ForEach(Array(lesson.quiz.enumerated()), id: \.offset) { index, quiz in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("\(index + 1). \(quiz.question)").font(.subheadline.bold())
                                    ForEach(Array(quiz.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                                        Button { answers[index] = choiceIndex } label: {
                                            HStack { Text(choice).font(.caption); Spacer(); if answers[index] == choiceIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.konsensGold) } }
                                                .padding(11).background(answers[index] == choiceIndex ? Color.konsensGold.opacity(0.09) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain)
                                    }
                                    if let answer = answers[index] {
                                        Text((answer == quiz.answer ? "Bonne réponse. " : "À revoir. ") + quiz.explanation)
                                            .font(.caption2).foregroundStyle(answer == quiz.answer ? Color.konsensPositive : Color.konsensGold)
                                    }
                                }
                            }
                            Button("Valider le module") { Task { await validate() } }
                                .font(.headline).foregroundStyle(Color(red: 0.06, green: 0.07, blue: 0.05))
                                .frame(maxWidth: .infinity).padding(14)
                                .background(Color.konsensGold, in: RoundedRectangle(cornerRadius: 15))
                                .disabled(answers.count < lesson.quiz.count).opacity(answers.count < lesson.quiz.count ? 0.35 : 1)
                            if let score {
                                Text("Score : \(score)% · \(score >= 70 ? "module maîtrisé" : "reprends les chapitres puis retente")")
                                    .font(.caption.bold()).foregroundStyle(score >= 70 ? Color.konsensPositive : Color.konsensGold)
                            }
                        }.academyPanel()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "À RETENIR")
                        ForEach(lesson.takeaways, id: \.self) { takeaway in Text("• \(takeaway)").font(.caption).foregroundStyle(Color.konsensMuted) }
                    }.academyPanel()

                    if let risk = lesson.riskNote {
                        Label(risk, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.konsensGold).padding(16)
                            .background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(18).padding(.bottom, 30)
            }
            .background(Color(red: 0.035, green: 0.047, blue: 0.039))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() }.foregroundStyle(Color.konsensGold) } }
        }
        .presentationBackground(Color(red: 0.035, green: 0.047, blue: 0.039))
        .onAppear { score = store.learningScores[lesson.id] }
    }

    private func validate() async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        let correct = lesson.quiz.enumerated().filter { answers[$0.offset] == $0.element.answer }.count
        let final = Int((Double(correct) / Double(max(lesson.quiz.count, 1)) * 100).rounded())
        struct Progress: Encodable { let user_id: UUID; let module_id: UUID; let completed_at: String; let score: Int }
        try? await store.supabase.from("learning_progress").upsert(Progress(user_id: userID, module_id: lesson.id, completed_at: ISO8601DateFormatter().string(from: Date()), score: final), onConflict: "user_id,module_id").execute()
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
            HStack(spacing: 5) { node("TX"); arrow; node("BLOC"); arrow; node("CONFIRM."); arrow; node("EXPLORATEUR") }.frame(maxWidth: .infinity).padding(.vertical, 24)
        case "rates-bonds":
            HStack { VStack { Text("TAUX"); Text("↑").font(.largeTitle).foregroundStyle(Color.konsensPositive) }; Spacer(); Rectangle().fill(Color.konsensMuted).frame(height: 2).rotationEffect(.degrees(-8)); Spacer(); VStack { Text("PRIX OBLIGATION"); Text("↓").font(.largeTitle).foregroundStyle(Color.konsensNegative) } }.font(.caption.bold()).padding(.vertical, 18)
        case "drawdown":
            VStack(alignment: .leading) { HStack(alignment: .bottom, spacing: 6) { ForEach([0.9,0.78,0.82,0.43,0.58,0.72,0.95], id: \.self) { v in Capsule().fill(v < 0.6 ? Color.konsensNegative : Color.konsensPositive.opacity(0.7)).frame(maxWidth: .infinity).frame(height: 120 * v) } }; Text("Une baisse profonde exige une récupération proportionnellement plus forte.").font(.caption2).foregroundStyle(Color.konsensMuted) }
        default:
            HStack(spacing: 16) { VStack { Text("ACHETEURS").font(.caption2); Text("99,90").bold(); Text("99,80") }; Text("SPREAD").font(.caption.bold()).foregroundStyle(Color.konsensGold); VStack { Text("VENDEURS").font(.caption2); Text("100,10").bold(); Text("100,20") } }.frame(maxWidth: .infinity).padding(.vertical, 24)
        }
    }
    private func node(_ label: String) -> some View { Text(label).font(.system(size: 8, weight: .bold)).padding(9).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9)) }
    private var arrow: some View { Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.konsensGold) }
}

private extension View {
    func academyPanel() -> some View {
        self.padding(16)
            .background(Color(red: 0.052, green: 0.070, blue: 0.058), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.konsensGold.opacity(0.09)))
    }
}
