import Foundation
import Combine
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdMobService: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var adsReady = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var lastError: String?

    // Google-provided test units. Replace with production AdMob units before App Store release.
    private let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
    private let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    private var rewardEarned = false
    private var activeAd: ActiveAd?
    private var rewardedContinuation: CheckedContinuation<Bool, Never>?
    private var interstitialContinuation: CheckedContinuation<Bool, Never>?

    private enum ActiveAd {
        case rewarded
        case interstitial
    }

    func configure() async {
        let parameters = RequestParameters()

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
                if let error {
                    self?.lastError = error.localizedDescription
                }
                continuation.resume()
            }
        }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            lastError = error.localizedDescription
        }

        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        guard ConsentInformation.shared.canRequestAds else {
            adsReady = false
            return
        }

        MobileAds.shared.start()
        adsReady = true
        await preloadAds()
    }

    func showRewarded() async -> Bool {
        guard adsReady else { return false }
        if rewardedAd == nil { await loadRewarded() }
        guard let ad = rewardedAd else { return false }

        rewardEarned = false
        activeAd = .rewarded
        rewardedAd = nil

        return await withCheckedContinuation { continuation in
            rewardedContinuation = continuation
            ad.present(from: nil) { [weak self] in
                self?.rewardEarned = true
            }
        }
    }

    func showInterstitial() async -> Bool {
        guard adsReady else { return false }
        if interstitialAd == nil { await loadInterstitial() }
        guard let ad = interstitialAd else { return false }

        activeAd = .interstitial
        interstitialAd = nil

        return await withCheckedContinuation { continuation in
            interstitialContinuation = continuation
            ad.present(from: nil)
        }
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func preloadAds() async {
        async let rewarded: Void = loadRewarded()
        async let interstitial: Void = loadInterstitial()
        _ = await (rewarded, interstitial)
    }

    private func loadRewarded() async {
        do {
            let ad = try await RewardedAd.load(with: rewardedUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
        } catch {
            rewardedAd = nil
            lastError = error.localizedDescription
        }
    }

    private func loadInterstitial() async {
        do {
            let ad = try await InterstitialAd.load(with: interstitialUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
        } catch {
            interstitialAd = nil
            lastError = error.localizedDescription
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch activeAd {
            case .rewarded:
                rewardedContinuation?.resume(returning: rewardEarned)
                rewardedContinuation = nil
                rewardEarned = false
                await loadRewarded()
            case .interstitial:
                interstitialContinuation?.resume(returning: true)
                interstitialContinuation = nil
                await loadInterstitial()
            case .none:
                break
            }
            activeAd = nil
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            lastError = error.localizedDescription
            switch activeAd {
            case .rewarded:
                rewardedContinuation?.resume(returning: false)
                rewardedContinuation = nil
                rewardEarned = false
                await loadRewarded()
            case .interstitial:
                interstitialContinuation?.resume(returning: false)
                interstitialContinuation = nil
                await loadInterstitial()
            case .none:
                break
            }
            activeAd = nil
        }
    }
}
