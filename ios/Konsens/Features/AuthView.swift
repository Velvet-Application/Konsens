import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                KonsensMark()
                Spacer(minLength: 26)
                Eyebrow(text: "1 000 KOINS OFFERTS")
                Text("Ton argent fictif.\nDe vraies leçons.")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(-1.6)
                Text("Prédis, investis, apprends. Construis un patrimoine virtuel et découvre ce que tes décisions peuvent réellement coûter.")
                    .foregroundStyle(Color.konsensMuted).font(.subheadline).lineSpacing(4)
                HStack(spacing: 7) {
                    Proof(text: "0 € réel")
                    Proof(text: "Finance expliquée")
                    Proof(text: "Risque visible")
                }
                VStack(spacing: 11) {
                    Button("Continuer avec Apple") { Task { try? await store.signIn(provider: .apple) } }.buttonStyle(AuthButton())
                    Button("Continuer avec Google") { Task { try? await store.signIn(provider: .google) } }.buttonStyle(AuthButton())
                    HStack { Rectangle().frame(height: 1); Text("OU").font(.system(size: 8)); Rectangle().frame(height: 1) }.foregroundStyle(Color.white.opacity(0.1))
                    TextField("Adresse mail", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).field()
                    SecureField("Mot de passe", text: $password).field()
                    if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(Color.konsensNegative) }
                    Button(isSignup ? "Créer mon portefeuille" : "Me connecter") {
                        Task {
                            do {
                                if isSignup { try await store.signUp(email: email, password: password) }
                                else { try await store.signIn(email: email, password: password) }
                            } catch { errorMessage = error.localizedDescription }
                        }
                    }.buttonStyle(PrimaryButton())
                    Button(isSignup ? "J’ai déjà un compte" : "Créer un compte") { isSignup.toggle() }
                        .font(.footnote.bold()).foregroundStyle(Color.konsensGreen)
                }.padding(18).background(Color.konsensPanel, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.07)))
                Text("Les Koins sont une unité virtuelle sans valeur monétaire. Konsens ne permet aucun dépôt, retrait ou conversion en argent.")
                    .font(.system(size: 8)).foregroundStyle(Color.konsensMuted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }.padding(24).frame(maxWidth: 520)
        }.background(Color.konsensBackground)
    }
}

struct NativeOnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date())!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KonsensMark()
                Spacer(minLength: 25)
                Eyebrow(text: "TON POINT DE DÉPART")
                Text("1 000 Koins.\nÀ toi de décider.").font(.largeTitle.bold())
                Text("Conserve-les, investis-les ou engage-les dans des prédictions. Ton patrimoine suivra chaque choix.").foregroundStyle(Color.konsensMuted)
                TextField("Pseudo public", text: $username).field()
                HStack { TextField("Prénom", text: $firstName).field(); TextField("Nom", text: $lastName).field() }
                DatePicker("Date de naissance", selection: $birthDate, in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!, displayedComponents: .date)
                Button("Recevoir mes 1 000 Koins") { Task { try? await store.completeProfile(username: username, firstName: firstName, lastName: lastName, birthDate: birthDate) } }
                    .buttonStyle(PrimaryButton()).disabled(username.count < 3 || firstName.isEmpty || lastName.isEmpty)
            }.padding(24)
        }.background(Color.konsensBackground)
    }
}

private struct Proof: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 8, weight: .bold)).padding(.horizontal, 9).padding(.vertical, 7).background(Color.white.opacity(0.04), in: Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.07))) }
}
private struct AuthButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.frame(maxWidth: .infinity).padding(14).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13)).opacity(configuration.isPressed ? 0.7 : 1) } }
private struct PrimaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).foregroundStyle(Color.konsensBackground).frame(maxWidth: .infinity).padding(15).background(Color.konsensGreen, in: RoundedRectangle(cornerRadius: 13)).opacity(configuration.isPressed ? 0.7 : 1) } }
private extension View { func field() -> some View { padding().background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.07))) } }
