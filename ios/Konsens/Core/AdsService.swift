import Foundation
import Combine
import GoogleMobileAds

@MainActor
final class AdsService: NSObject, ObservableObject {
    static let shared = AdsService()

    @Published private(set) var rewardedReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var rewardedAd: RewardedAd?
    private var pendingReward: (() -> Void)?

    // Google official iOS test unit. Replace with the Konsens production unit before App Store release.
    private let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    private override init() {
        super.init()
        MobileAds.shared.start()
        Task { await loadRewarded() }
    }

    func loadRewarded(force: Bool = false) async {
        guard !isLoading else { return }
        if rewardedAd != nil, !force {
            rewardedReady = true
            return
        }

        isLoading = true
        lastError = nil
        do {
            rewardedAd = try await RewardedAd.load(with: rewardedUnitID, request: Request())
            rewardedReady = true
        } catch {
            rewardedAd = nil
            rewardedReady = false
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    /// Returns true when presentation can start. For a free player, the bet action is
    /// executed only from Google's earned-reward callback.
    @discardableResult
    func presentRewarded(onReward: @escaping () -> Void) -> Bool {
        guard let ad = rewardedAd else {
            Task { await loadRewarded(force: true) }
            return false
        }

        rewardedAd = nil
        rewardedReady = false
        pendingReward = onReward

        // Start preparing the next rewarded ad immediately; the displayed instance remains alive locally.
        Task { await loadRewarded(force: true) }

        ad.present(from: nil) { [weak self] in
            guard let self else { return }
            let rewardAction = self.pendingReward
            self.pendingReward = nil
            rewardAction?()
        }
        return true
    }
}
