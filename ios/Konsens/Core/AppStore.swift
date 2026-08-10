import Foundation
import Supabase

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .arena
    @Published var isAuthenticated = false
    @Published var onboardingComplete = false
    @Published var isLoading = true
    @Published var credits = 0
    @Published var streak = 0
    @Published var dailyAnswer: Bool?
    @Published var activeMarket: Market?
    @Published var toast: String?
    @Published var markets: [Market] = []
    @Published var positions: [Position] = []
    @Published var leaders: [Leader] = []

    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://mxuevsspybxoovsutsbs.supabase.co")!,
        supabaseKey: "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7"
    )

    init() { Task { await restoreSession() } }
    func restoreSession() async { isAuthenticated = supabase.auth.currentSession != nil; if isAuthenticated { await loadProfile() }; isLoading = false }
    func signIn(email: String, password: String) async throws { try await supabase.auth.signIn(email: email, password: password); isAuthenticated = true; await loadProfile() }
    func signUp(email: String, password: String) async throws { try await supabase.auth.signUp(email: email, password: password); showToast("Vérifie ta boîte mail pour confirmer ton inscription") }
    func signIn(provider: Provider) async throws { try await supabase.auth.signInWithOAuth(provider: provider, redirectTo: URL(string: "konsens://auth-callback")) }
    func completeProfile(username: String, firstName: String, lastName: String, birthDate: Date) async throws {
        struct Update: Encodable { let username:String;let first_name:String;let last_name:String;let birth_date:String;let onboarding_completed_at:String }
        let day=DateFormatter();day.dateFormat="yyyy-MM-dd"
        let update=Update(username:username,first_name:firstName,last_name:lastName,birth_date:day.string(from:birthDate),onboarding_completed_at:ISO8601DateFormatter().string(from:Date()))
        try await supabase.from("profiles").update(update).eq("id",value:supabase.auth.currentUser!.id).execute()
        onboardingComplete=true
    }
    func loadProfile() async { guard let id=supabase.auth.currentUser?.id else{return};struct Row:Decodable{let onboarding_completed_at:String?};if let row:Row=try? await supabase.from("profiles").select("onboarding_completed_at").eq("id",value:id).single().execute().value{onboardingComplete=row.onboarding_completed_at != nil} }
    func signOut() async { try? await supabase.auth.signOut();isAuthenticated=false;onboardingComplete=false }
    func answerDaily(_ answer:Bool){dailyAnswer=answer}
    func buy(outcome:Bool){activeMarket=nil}
    func showToast(_ message:String){toast=message;Task{try? await Task.sleep(for:.seconds(2));if toast==message{toast=nil}}}
}
