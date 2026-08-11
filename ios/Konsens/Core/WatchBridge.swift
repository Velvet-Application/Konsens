import Foundation
import WatchConnectivity

final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var timer: Timer?

    private override init() {
        super.init()
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    func start() {
        sendSnapshot()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.sendSnapshot() }
    }

    func sendSnapshot() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let defaults = UserDefaults(suiteName: "group.com.konsens.beta") else { return }
        var context: [String: Any] = [
            "wealth": defaults.integer(forKey: "konsens_widget_wealth"),
            "performance": defaults.double(forKey: "konsens_widget_performance"),
            "score": defaults.integer(forKey: "konsens_widget_score"),
            "archetype": defaults.string(forKey: "konsens_widget_archetype") ?? "Profil en construction",
            "dailyTitle": defaults.string(forKey: "konsens_widget_daily_title") ?? "Ton Konsens du jour",
            "dailyNext": defaults.string(forKey: "konsens_widget_daily_next") ?? "Ouvre Konsens sur iPhone",
            "dailyProgress": defaults.integer(forKey: "konsens_widget_daily_progress"),
            "updated": defaults.double(forKey: "konsens_widget_updated")
        ]
        if let markets = defaults.data(forKey: "konsens_widget_markets") { context["markets"] = markets }
        if let assets = defaults.data(forKey: "konsens_widget_assets") { context["assets"] = assets }
        try? WCSession.default.updateApplicationContext(context)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { if activationState == .activated { sendSnapshot() } }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
