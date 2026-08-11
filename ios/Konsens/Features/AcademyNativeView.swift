import SwiftUI

struct AcademyNativeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected: LearningLesson?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 13) {
                Eyebrow(text: "KONSENS ACADEMY · CURSUS COMPLET")
                Text("Comprendre avant\nde risquer.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("\(store.lessons.count) modules détaillés · chapitres, exemples, schémas, vidéos et quiz. Un vrai parcours de connaissances, pas un glossaire.")
                    .font(.subheadline).foregroundStyle(Color.konsensMuted)
                    .padding(.bottom, 8)

                ForEach(store.lessons) { lesson in
                    Button { selected = lesson } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Text(String(format: "%02d", lesson.position))
                                .font(.title2.monospacedDigit().bold())
                                .foregroundStyle(Color.konsensGreen.opacity(0.45))
                                .frame(width: 38)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    Text(lesson.level.uppercased()).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensGreen)
                                    Text("\(lesson.durationMinutes) MIN").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensMuted)
                                    Text("+\(lesson.xpReward) XP").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.konsensViolet)
                                }
                                Text(lesson.title).font(.headline)
                                Text(lesson.summary).font(.caption).foregroundStyle(Color.konsensMuted).lineLimit(3)
                                HStack(spacing: 8) {
                                    Label("\(lesson.chapters.count) chapitres", systemImage: "text.book.closed")
                                    Label("\(lesson.quiz.count) quiz", systemImage: "checkmark.circle")
                                }.font(.system(size: 8)).foregroundStyle(Color.konsensMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.konsensGreen)
                        }.panel()
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.top, 92).padding(.bottom, 110)
        }
        .sheet(item: $selected) { lesson in
            CourseSheet(lesson: lesson).environmentObject(store)
        }
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
                        Text(lesson.title).font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("\(lesson.durationMinutes) min · \(lesson.level) · +\(lesson.xpReward) XP")
                            .font(.caption).foregroundStyle(Color.konsensMuted)
                        Text(lesson.concept).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "OBJECTIFS")
                        ForEach(lesson.objectives, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.konsensPositive)
                        }
                    }.panel()

                    if !lesson.chapters.isEmpty {
                        Picker("Chapitre", selection: $chapter) {
                            ForEach(Array(lesson.chapters.enumerated()), id: \.offset) { index, _ in
                                Text("\(index + 1)").tag(index)
                            }
                        }.pickerStyle(.segmented)

                        let current = lesson.chapters[min(chapter, lesson.chapters.count - 1)]
                        VStack(alignment: .leading, spacing: 14) {
                            Text(current.title).font(.title2.bold())
                            Text(current.body).font(.body).lineSpacing(6)
                            if let example = current.example {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EXEMPLE CONCRET").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.konsensBlue)
                                    Text(example).font(.subheadline).foregroundStyle(Color.konsensMuted).lineSpacing(4)
                                }.padding(16).background(Color.konsensBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                            if let callout = current.callout {
                                Label(callout, systemImage: "lightbulb.fill")
                                    .font(.caption.bold()).foregroundStyle(Color.konsensGreen)
                                    .padding(14).background(Color.konsensGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }.panel()
                    }

                    if let diagram = lesson.media.first(where: { $0.type == "diagram" }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "SCHÉMA")
                            Text(diagram.title).font(.headline)
                            NativeDiagram(kind: diagram.kind)
                        }.panel()
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
                                        Image(systemName: media.type == "video" ? "play.rectangle.fill" : "arrow.up.forward.square")
                                            .foregroundStyle(Color.konsensBlue)
                                        VStack(alignment: .leading) {
                                            Text(media.title).font(.subheadline.bold())
                                            Text(media.source ?? "Ressource").font(.caption2).foregroundStyle(Color.konsensMuted)
                                        }
                                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.konsensMuted)
                                    }.padding(12).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
                                }.buttonStyle(.plain)
                            }
                        }.panel()
                    }

                    if chapter == max(lesson.chapters.count - 1, 0) && !lesson.quiz.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "VALIDATION")
                            Text("Teste ta compréhension.").font(.title2.bold())
                            ForEach(Array(lesson.quiz.enumerated()), id: \.offset) { index, quiz in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("\(index + 1). \(quiz.question)").font(.subheadline.bold())
                                    ForEach(Array(quiz.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                                        Button { answers[index] = choiceIndex } label: {
                                            HStack { Text(choice).font(.caption); Spacer(); if answers[index] == choiceIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.konsensViolet) } }
                                                .padding(11).background(answers[index] == choiceIndex ? Color.konsensViolet.opacity(0.1) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain)
                                    }
                                    if let answer = answers[index] {
                                        Text((answer == quiz.answer ? "Bonne réponse. " : "À revoir. ") + quiz.explanation)
                                            .font(.caption2).foregroundStyle(answer == quiz.answer ? Color.konsensPositive : Color.konsensGold)
                                    }
                                }
                            }
                            Button("Valider le module") { Task { await validate() } }
                                .font(.headline).foregroundStyle(Color.konsensBackground)
                                .frame(maxWidth: .infinity).padding(14)
                                .background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 15))
                                .disabled(answers.count < lesson.quiz.count).opacity(answers.count < lesson.quiz.count ? 0.35 : 1)
                            if let score {
                                Text("Score : \(score)% · \(score >= 70 ? "module maîtrisé" : "reprends les chapitres puis retente")")
                                    .font(.caption.bold()).foregroundStyle(score >= 70 ? Color.konsensPositive : Color.konsensGold)
                            }
                        }.panel()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "À RETENIR")
                        ForEach(lesson.takeaways, id: \.self) { takeaway in Text("• \(takeaway)").font(.caption).foregroundStyle(Color.konsensMuted) }
                    }.panel()

                    if let risk = lesson.riskNote {
                        Label(risk, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.konsensGold).padding(16)
                            .background(Color.konsensGold.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(18).padding(.bottom, 30)
            }
            .background(Color.konsensBackground)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        }
        .presentationBackground(Color.konsensBackground)
    }

    private func validate() async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        let correct = lesson.quiz.enumerated().filter { answers[$0.offset] == $0.element.answer }.count
        let final = Int((Double(correct) / Double(max(lesson.quiz.count, 1)) * 100).rounded())
        struct Progress: Encodable { let user_id: UUID; let module_id: UUID; let completed_at: String; let score: Int }
        try? await store.supabase.from("learning_progress").upsert(Progress(user_id: userID, module_id: lesson.id, completed_at: ISO8601DateFormatter().string(from: Date()), score: final), onConflict: "user_id,module_id").execute()
        score = final
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
            HStack { VStack { Text("TAUX"); Text("↑").font(.largeTitle).foregroundStyle(Color.konsensGreen) }; Spacer(); Rectangle().fill(Color.konsensMuted).frame(height: 2).rotationEffect(.degrees(-8)); Spacer(); VStack { Text("PRIX OBLIGATION"); Text("↓").font(.largeTitle).foregroundStyle(Color.konsensNegative) } }.font(.caption.bold()).padding(.vertical, 18)
        case "drawdown":
            VStack(alignment: .leading) { HStack(alignment: .bottom, spacing: 6) { ForEach([0.9,0.78,0.82,0.43,0.58,0.72,0.95], id: \.self) { v in Capsule().fill(v < 0.6 ? Color.konsensNegative : Color.konsensGreen.opacity(0.7)).frame(maxWidth: .infinity).frame(height: 120 * v) } }; Text("Une baisse profonde exige une récupération proportionnellement plus forte.").font(.caption2).foregroundStyle(Color.konsensMuted) }
        default:
            HStack(spacing: 16) { VStack { Text("ACHETEURS").font(.caption2); Text("99,90").bold(); Text("99,80") }; Text("SPREAD").font(.caption.bold()).foregroundStyle(Color.konsensGold); VStack { Text("VENDEURS").font(.caption2); Text("100,10").bold(); Text("100,20") } }.frame(maxWidth: .infinity).padding(.vertical, 24)
        }
    }
    private func node(_ label: String) -> some View { Text(label).font(.system(size: 8, weight: .bold)).padding(9).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9)) }
    private var arrow: some View { Image(systemName: "arrow.right").font(.caption).foregroundStyle(Color.konsensGreen) }
}
