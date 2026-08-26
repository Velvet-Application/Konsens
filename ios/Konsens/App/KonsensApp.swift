import SwiftUI

@main
struct KonsensApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var ads = AdMobService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(ads)
                .task { await ads.configure() }
                .onOpenURL { url in
                    Task {
                        do {
                            try await store.supabase.auth.session(from: url)
                            await store.restoreSession()
                        } catch {
                            store.showToast("Lien de connexion invalide ou expiré")
                        }
                    }
                }
        }
    }
}
