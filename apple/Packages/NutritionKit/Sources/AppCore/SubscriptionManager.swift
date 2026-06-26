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
    /// Loaded products — prices and terms come from the store, already localized.
    public private(set) var products: [Product] = []
    public private(set) var isLoadingProducts = false
    /// True while a purchase is in flight (drives the paywall button's spinner).
    public private(set) var isPurchasing = false

    /// Demo / UI-test / `-subscribed`: pretend Pro so nothing is gated and no
    /// StoreKit calls are made.
    private let forced: Bool
    private var listener: Task<Void, Never>?

    public init(bypassed: Bool = false) {
        forced = bypassed || ProcessInfo.processInfo.arguments.contains("-subscribed")
        if forced {
            isSubscribed = true
            return
        }
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
        if forced { isSubscribed = true; return }
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result,
                  Self.productIDs.contains(txn.productID),
                  txn.revocationDate == nil else { continue }
            if let expires = txn.expirationDate, expires <= Date() { continue }   // lapsed
            active = true
        }
        isSubscribed = active
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
                    await updateEntitlement()
                    return isSubscribed
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
