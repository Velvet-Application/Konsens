import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class KonsensPrivacyConsentManager: ObservableObject {
    static let shared = KonsensPrivacyConsentManager()

    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var lastError: String?

    private var requestedThisLaunch = false
    private var mobileAdsStarted = false

    private init() {
        syncState()
    }

    func gatherConsent() async {
        if requestedThisLaunch {
            syncState()
            startMobileAdsIfAllowed()
            return
        }

        requestedThisLaunch = true
        let parameters = RequestParameters()

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(returning: ())
                        return
                    }

                    if let error {
                        lastError = error.localizedDescription
                    } else {
                        do {
                            try await ConsentForm.loadAndPresentIfRequired(from: nil)
                            lastError = nil
                        } catch {
                            lastError = error.localizedDescription
                        }
                    }

                    syncState()
                    startMobileAdsIfAllowed()
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func ensureAdsAllowed() async -> Bool {
        await gatherConsent()
        syncState()
        startMobileAdsIfAllowed()
        return canRequestAds
    }

    func presentPrivacyOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        syncState()
        startMobileAdsIfAllowed()
    }

    private func syncState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func startMobileAdsIfAllowed() {
        guard canRequestAds, !mobileAdsStarted else { return }
        mobileAdsStarted = true
        MobileAds.shared.start()
    }
}
