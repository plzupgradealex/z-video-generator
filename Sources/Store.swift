import Foundation
import StoreKit

/// In-app purchase for "Z Video Generator Supporter" — a purely cosmetic
/// thank-you (a gold mark + the supporter state in About), never a feature gate
/// and never video credits. StoreKit 2 verifies transactions on-device, so
/// there's no server. The product `com.alex.ZVideoGenerator.supporter` must
/// exist in App Store Connect for a real purchase to resolve; until then the
/// About button explains purchases aren't available yet instead of looking dead,
/// and resolves automatically once the product goes live.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    nonisolated static let productID = "com.alex.ZVideoGenerator.supporter"

    /// True entitlement from a completed/verified transaction.
    @Published private(set) var isSupporter = false

    /// One-line note for the About button when a Support tap can't complete a
    /// real purchase (no product configured yet, StoreKit unreachable, or the
    /// user deferred/cancelled). Nil when there's nothing to say — set only so
    /// the About sheet can show *why* the button did nothing instead of looking
    /// broken.
    @Published private(set) var purchaseNote: String?
    func clearPurchaseNote() { purchaseNote = nil }

    private var listener: Task<Void, Never>?

    /// One-time preview override so the supporter look can be eyeballed before
    /// the ASC product / Paid Apps agreement exist. Cosmetic only:
    /// `defaults write com.alex.ZVideoGenerator zvg.supporter.preview -bool true`.
    private var previewOverride: Bool {
        UserDefaults.standard.bool(forKey: "zvg.supporter.preview")
    }

    /// What the UI should treat as "supporter": real entitlement OR the preview flag.
    var supporter: Bool { isSupporter || previewOverride }

    init() {
        listener = listenForTransactions()
        Task { await refresh() }
    }

    deinit { listener?.cancel() }

    func purchase() async {
        guard !previewOverride else {      // preview is already "on"
            purchaseNote = "Supporter preview is on — the supporter mark is already active."
            return
        }
        do {
            let products = try await Product.products(for: [Self.productID])
            // The IAP isn't in App Store Connect yet, so this returns empty for
            // now. Tell the user why instead of looking like a dead button; it
            // resolves automatically once the product goes live.
            guard let product = products.first else {
                purchaseNote = "Supporter purchases aren't available yet — they'll arrive when Z Video Generator is on the App Store."
                return
            }
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                await apply(transaction)
            }
            // A deferred/cancelled purchase: nothing to report.
        } catch {
            purchaseNote = "Couldn't reach the App Store. \(error.localizedDescription)"
        }
    }

    private func apply(_ t: Transaction) async {
        if !isSupporter { isSupporter = true }
        await t.finish()
    }

    /// Restore/observe entitlement on launch (covers reinstalls / new Macs).
    private func refresh() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID {
                isSupporter = true
                return
            }
        }
    }

    /// Catch transactions/refunds that land while the app runs. Non-detached so
    /// it inherits the class's `@MainActor` isolation — avoids capturing `self`
    /// in a `@Sendable` detached closure (a Swift 6 error). The `for await`
    /// suspends rather than blocks the main actor.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let t) = result else { continue }
                guard t.productID == Self.productID else { continue }
                await t.finish()
                self?.isSupporter = true
            }
        }
    }
}
