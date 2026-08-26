import Foundation
import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var isSubmitting = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        normalizedEmail.contains("@") && normalizedEmail.contains(".") && password.count >= 6 && !isSubmitting
    }

    var body: some View {
        ZStack {
            GameAuthBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    KonsensMark()
                    Spacer(minLength: 24)

                    HStack(spacing: 8) {
                        AuthPill(text: "1 000 K OFFERTS", tint: Color.konsensGold)
                        AuthPill(text: "0 € RÉEL", tint: Color.konsensGreen)
                    }

                    Text("Deviens plus riche\nque tes potes.")
                        .font(.system(size: 43, weight: .black, design: .rounded))
                        .tracking(-1.8)
                        .minimumScaleFactor(0.85)

                    Text("Parie sur des sujets fun, investis tes Koins, grimpe dans ta ligue et chambre ceux qui restent derrière.")
                        .foregroundStyle(Color.white.opacity(0.76))
                        .font(.subheadline.weight(.semibold))
                        .lineSpacing(4)

                    HStack(spacing: 7) {
                        Proof(text: "Paris entre potes")
                        Proof(text: "Classement")
                        Proof(text: "Koins quotidiens")
                    }

                    VStack(spacing: 11) {
                        Button("Continuer avec Apple") { Task { try? await store.signIn(provider: .apple) } }
                            .buttonStyle(AuthButton())
                        Button("Continuer avec Google") { Task { try? await store.signIn(provider: .google) } }
                            .buttonStyle(AuthButton())

                        HStack {
                            Rectangle().frame(height: 1)
                            Text("OU").font(.system(size: 8, weight: .black))
                            Rectangle().frame(height: 1)
                        }
                        .foregroundStyle(Color.white.opacity(0.12))

                        TextField("Adresse mail", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .field()
                        SecureField("Mot de passe", text: $password)
                            .textContentType(isSignup ? .newPassword : .password)
                            .field()

                        if !errorMessage.isEmpty {
                            Text(errorMessage).font(.caption).foregroundStyle(Color.konsensNegative).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !successMessage.isEmpty {
                            Text(successMessage).font(.caption.weight(.semibold)).foregroundStyle(Color.konsensGreen).frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button { submit() } label: {
                            HStack(spacing: 8) {
                                if isSubmitting { ProgressView().tint(Color.konsensBackground) }
                                Text(isSubmitting ? "Chargement…" : (isSignup ? "ENTRER DANS LE JEU" : "REPRENDRE MA PARTIE"))
                            }
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canSubmit)
                        .opacity(canSubmit || isSubmitting ? 1 : 0.55)

                        Button(isSignup ? "J’ai déjà un compte" : "Créer mon joueur") {
                            isSignup.toggle()
                            errorMessage = ""
                            successMessage = ""
                        }
                        .disabled(isSubmitting)
                        .font(.footnote.bold())
                        .foregroundStyle(Color.konsensGold)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.09)))

                    Text("18+ · Les Koins sont une unité virtuelle sans valeur monétaire. Aucun dépôt, retrait ou conversion en argent réel.")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.konsensMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
                .frame(maxWidth: 520)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func submit() {
        guard canSubmit else {
            if normalizedEmail.isEmpty || !normalizedEmail.contains("@") || !normalizedEmail.contains(".") {
                errorMessage = "Saisis une adresse e-mail valide."
            } else if password.count < 6 {
                errorMessage = "Le mot de passe doit contenir au moins 6 caractères."
            }
            return
        }

        isSubmitting = true
        errorMessage = ""
        successMessage = ""
        let cleanEmail = normalizedEmail

        Task {
            defer { isSubmitting = false }
            do {
                if isSignup {
                    try await store.signUp(email: cleanEmail, password: password)
                    if store.supabase.auth.currentSession != nil {
                        await store.restoreSession()
                    } else {
                        successMessage = "Compte créé. Confirme ton e-mail puis reviens récupérer tes Koins."
                    }
                } else {
                    try await store.signIn(email: cleanEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct NativeOnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date())!

    var body: some View {
        ZStack {
            GameAuthBackdrop().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    KonsensMark()
                    Spacer(minLength: 24)
                    Eyebrow(text: "TON JOUEUR")
                    Text("1 000 Koins.\nFais-en quelque chose.")
                        .font(.system(size: 39, weight: .black, design: .rounded))
                        .tracking(-1.4)
                    Text("Ton pseudo sera visible dans ta ligue. Tes amis verront ton classement, tes gros coups… et tes gamelles.")
                        .foregroundStyle(Color.white.opacity(0.74))
                    TextField("Pseudo public", text: $username).field()
                    HStack {
                        TextField("Prénom", text: $firstName).field()
                        TextField("Nom", text: $lastName).field()
                    }
                    DatePicker(
                        "Date de naissance",
                        selection: $birthDate,
                        in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                        displayedComponents: .date
                    )
                    .font(.subheadline.bold())

                    Button("RÉCUPÉRER MES 1 000 K") {
                        Task { try? await store.completeProfile(username: username, firstName: firstName, lastName: lastName, birthDate: birthDate) }
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(username.count < 3 || firstName.isEmpty || lastName.isEmpty)
                }
                .padding(24)
            }
        }
    }
}

private struct GameAuthBackdrop: View {
    var body: some View {
        ZStack {
            Color.konsensBackground
            RadialGradient(colors: [Color.konsensViolet.opacity(0.46), .clear], center: .topTrailing, startRadius: 0, endRadius: 430)
            RadialGradient(colors: [Color.konsensPink.opacity(0.22), .clear], center: .centerLeading, startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Color.konsensGold.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 300)
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.konsensGold.opacity(0.08) : Color.konsensViolet.opacity(0.08))
                    .frame(width: CGFloat(28 + index * 12), height: CGFloat(28 + index * 12))
                    .offset(x: CGFloat((index % 3) * 140 - 130), y: CGFloat(index * 95 - 330))
            }
        }
    }
}

private struct AuthPill: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.20)))
    }
}

private struct Proof: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.07)))
    }
}

private struct AuthButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.konsensBackground)
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(LinearGradient(colors: [Color.konsensGold, Color.konsensGreen], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private extension View {
    func field() -> some View {
        padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }
}
