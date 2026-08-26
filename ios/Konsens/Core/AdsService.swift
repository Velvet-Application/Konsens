import Foundation
import GoogleMobileAds

@MainActor
final class AdsService: NSObject, ObservableObject, FullScreenContentDelegate {
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
        if rewardedAd != nil, !force { rewardedReady = true; return }

        isLoading = true
        lastError = nil
        do {
            let ad = try await RewardedAd.load(with: rewardedUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            rewardedReady = true
        } catch {
            rewardedAd = nil
            rewardedReady = false
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    /// Returns true when the ad presentation has started. The action is executed only after
    /// Google reports that the user earned the reward, which makes it suitable as the free-player bet gate.
    @discardableResult
    func presentRewarded(onReward: @escaping () -> Void) -> Bool {
        guard let ad = rewardedAd else {
            Task { await loadRewarded(force: true) }
            return false
        }

        rewardedAd = nil
        rewardedReady = false
        pendingReward = onReward
        ad.present(from: nil) { [weak self] in
            guard let self else { return }
            let rewardAction = self.pendingReward
            self.pendingReward = nil
            rewardAction?()
        }
        return true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        pendingReward = nil
        Task { await loadRewarded(force: true) }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        pendingReward = nil
        lastError = error.localizedDescription
        rewardedReady = false
        Task { await loadRewarded(force: true) }
    }
}
