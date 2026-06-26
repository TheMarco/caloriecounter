//
//  SubscriptionManager.swift
//  The whole "is this person Pro?" question, answered ON DEVICE against the
//  signed-in Apple ID — no account, no server. `Transaction.currentEntitlements`
//  is the source of truth (cryptographically verified by StoreKit), and a
//  `Transaction.updates` listener keeps it live across renewals, refunds, and
//  purchases made on the user's other devices.
//

import Foundation
import Observation
import StoreKit

@Observable
@MainActor
public final class SubscriptionManager {

    /// Auto-renewable subscription product IDs. These MUST match the products
    /// created in App Store Connect and the bundled `CalorieCounter.storekit`
    /// test configuration.
    nonisolated public static let monthlyID = "com.aidashcreated.caloriecounter.pro.monthly"
    nonisolated public static let yearlyID  = "com.aidashcreated.caloriecounter.pro.yearly"
    nonisolated public static var productIDs: [String] { [monthlyID, yearlyID] }

    /// Whether the user currently holds an active Pro entitlement.
    public private(set) var isSubscribed = false
    /// True once the entitlement has been determined at least once (or is known
    /// up-front via a forced/pinned flag). Until then the free-tier gate gives the
    /// benefit of the doubt and does NOT block — a real subscriber must never be
    /// locked out while StoreKit is still warming up at cold launch.
    public private(set) var entitlementResolved = false
    /// Loaded products — prices and terms come from the store, already localized.
    public private(set) var products: [Product] = []
    public private(set) var isLoadingProducts = false
    /// True while a purchase is in flight (drives the paywall button's spinner).
    public private(set) var isPurchasing = false

    /// Demo / UI-test / `-subscribed`: pretend Pro so nothing is gated and no
    /// StoreKit calls are made.
    private let forced: Bool
    /// `-gate`: pin as a non-subscriber so the free-tier paywall can actually be
    /// exercised even when a leftover entitlement exists (a StoreKit-test or sandbox
    /// purchase from a prior run). Products still load, so the paywall shows real plans.
    /// Cleared the moment a genuine purchase or restore succeeds, so the gate simulation
    /// never swallows a real entitlement (relaunching with `-gate` re-arms it).
    private var pinnedUnsubscribed: Bool
    private var listener: Task<Void, Never>?

    public init(bypassed: Bool = false) {
        let args = ProcessInfo.processInfo.arguments
        forced = bypassed || args.contains("-subscribed")
        pinnedUnsubscribed = !forced && args.contains("-gate")
        if forced {
            isSubscribed = true
            entitlementResolved = true
            return
        }
        // `-gate` knows the answer up-front (not subscribed); otherwise the entitlement
        // resolves asynchronously in the first `refresh()` below.
        entitlementResolved = pinnedUnsubscribed
        listener = listenForTransactions()
        Task { await refresh() }
    }

    /// Reload products and re-evaluate the entitlement.
    public func refresh() async {
        await loadProducts()
        await updateEntitlement()
    }

    public func loadProducts() async {
        guard !forced else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }   // monthly (cheaper) first
        } catch {
            products = []
        }
    }

    /// The on-device entitlement check — the heart of "no account needed". Asks
    /// StoreKit which products this Apple ID currently owns; each result is a
    /// verified, signed transaction.
    public func updateEntitlement() async {
        if forced { isSubscribed = true; entitlementResolved = true; return }
        if pinnedUnsubscribed { isSubscribed = false; entitlementResolved = true; return }
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result,
                  Self.productIDs.contains(txn.productID),
                  txn.revocationDate == nil else { continue }
            if let expires = txn.expirationDate, expires <= Date() { continue }   // lapsed
            active = true
        }
        isSubscribed = active
        entitlementResolved = true
    }

    /// Buy a plan. Returns true once the purchase verifies and Pro is unlocked.
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    // A verified purchase is definitive: unlock now and drop any `-gate`
                    // pin so it can't immediately re-flag us as unsubscribed. (The next
                    // entitlement refresh then reads the real, now-active entitlement.)
                    pinnedUnsubscribed = false
                    isSubscribed = true
                    entitlementResolved = true
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restore Purchases — force a sync with the App Store, then re-check. Required
    /// by App Review; entitlements normally restore automatically via the listener.
    public func restore() async {
        try? await AppStore.sync()
        pinnedUnsubscribed = false   // an explicit restore wins over the gate simulation
        await updateEntitlement()
    }

    // MARK: - Display helpers

    public var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    public var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }

    /// Yearly savings vs paying monthly for a year, rounded — for the "Save N%" badge.
    public var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct?.price, let yearly = yearlyProduct?.price, monthly > 0 else { return nil }
        let annualAtMonthly = monthly * 12
        let fraction = (annualAtMonthly - yearly) / annualAtMonthly
        let pct = Int((fraction as NSDecimalNumber).doubleValue * 100)
        return pct > 0 ? pct : nil
    }

    /// A localized free-trial line for a product, if it offers an introductory trial.
    public func trialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day:   unit = "day"
        case .week:  unit = "week"
        case .month: unit = "month"
        case .year:  unit = "year"
        @unknown default: unit = "day"
        }
        // Normalize a 1-week trial to the friendlier "7-day".
        if offer.period.unit == .week { return "\(n * 7)-day free trial" }
        return "\(n)-\(unit) free trial"
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let txn) = update {
                    await txn.finish()
                }
                await self.updateEntitlement()
            }
        }
    }
}
