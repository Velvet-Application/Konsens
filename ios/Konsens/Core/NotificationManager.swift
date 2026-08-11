import Foundation
import UserNotifications
import Supabase
import WidgetKit

struct KonsensNotification: Identifiable, Decodable, Hashable {
    let id: UUID
    let kind: String
    let title: String
    let body: String
    let created_at: String
    let read_at: String?
}

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var events: [KonsensNotification] = []
    @Published var authorization: UNAuthorizationStatus = .notDetermined
    private var pollTask: Task<Void, Never>?
    private var seen = Set<UUID>()

    private init() {
        Task { await refreshAuthorization() }
    }

    var unreadCount: Int {
        events.filter { $0.read_at == nil }.count
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestPermission(store: AppStore) async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorization()
            guard let userID = store.supabase.auth.currentUser?.id else { return }

            struct Pref: Encodable {
                let user_id: UUID
                let ios_enabled: Bool
                let updated_at: String
            }

            try? await store.supabase
                .from("notification_preferences")
                .upsert(
                    Pref(
                        user_id: userID,
                        ios_enabled: granted,
                        updated_at: ISO8601DateFormatter().string(from: Date())
                    ),
                    onConflict: "user_id"
                )
                .execute()

            store.showToast(granted ? "Notifications Konsens activées" : "Notifications non autorisées")
        } catch {
            store.showToast("Impossible d’activer les notifications")
        }
    }

    func start(store: AppStore) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(store: store, announceNew: true)
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(store: AppStore, announceNew: Bool = false) async {
        guard let userID = store.supabase.auth.currentUser?.id else { return }
        let mapped: [KonsensNotification] = (try? await store.supabase
            .from("notification_events")
            .select("id,kind,title,body,created_at,read_at")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(40)
            .execute().value) ?? []

        if announceNew && authorization == .authorized {
            for event in mapped.reversed() where !seen.contains(event.id) && event.read_at == nil {
                await scheduleLocal(event)
            }
        }

        events = mapped
        seen.formUnion(mapped.map(\.id))
        await syncJourneySnapshot(store: store)
    }

    func markRead(_ event: KonsensNotification, store: AppStore) async {
        let stamp = ISO8601DateFormatter().string(from: Date())
        try? await store.supabase
            .from("notification_events")
            .update(["read_at": stamp])
            .eq("id", value: event.id)
            .execute()

        events = events.map {
            $0.id == event.id
                ? KonsensNotification(
                    id: $0.id,
                    kind: $0.kind,
                    title: $0.title,
                    body: $0.body,
                    created_at: $0.created_at,
                    read_at: stamp
                )
                : $0
        }
    }

    private func syncJourneySnapshot(store: AppStore) async {
        struct Empty: Encodable {}
        struct ScoreRow: Decodable {
            let total_score: Double
            let archetype: String
            let streak_days: Int
        }
        struct SessionRow: Decodable {
            let understand_completed_at: String?
            let predict_completed_at: String?
            let decide_completed_at: String?
            let learn_completed_at: String?
        }
        guard let defaults = UserDefaults(suiteName: "group.com.konsens.beta") else { return }
        let scoreRows: [ScoreRow] = (try? await store.supabase.rpc("get_my_konsens_score", params: Empty()).execute().value) ?? []
        let session: SessionRow? = try? await store.supabase.rpc("ensure_daily_session", params: Empty()).single().execute().value
        if let score = scoreRows.first {
            defaults.set(Int(score.total_score.rounded()), forKey: "konsens_journey_score")
            defaults.set(score.archetype, forKey: "konsens_journey_archetype")
            defaults.set(score.streak_days, forKey: "konsens_journey_streak")
        }
        if let session {
            let completed = [session.understand_completed_at, session.predict_completed_at, session.decide_completed_at, session.learn_completed_at].filter { $0 != nil }.count
            let next = session.understand_completed_at == nil ? "Comprendre" : session.predict_completed_at == nil ? "Prédire" : session.decide_completed_at == nil ? "Décider" : session.learn_completed_at == nil ? "Apprendre" : "Terminé"
            defaults.set(completed, forKey: "konsens_journey_progress")
            defaults.set(next, forKey: "konsens_journey_next")
        }
        defaults.set(Date().timeIntervalSince1970, forKey: "konsens_widget_updated")
        WidgetCenter.shared.reloadAllTimelines()
        WatchBridge.shared.sendSnapshot()
    }

    private func scheduleLocal(_ event: KonsensNotification) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.userInfo = ["kind": event.kind]
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
        )
    }
}
