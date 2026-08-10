import SwiftUI

@main
struct KonsensApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onOpenURL { url in Task { try? await store.supabase.auth.session(from: url) } }
        }
    }
}
