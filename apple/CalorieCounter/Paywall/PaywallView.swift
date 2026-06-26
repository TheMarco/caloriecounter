//
//  PaywallView.swift
//  Shown when a non-subscriber hits the free-entry limit (or taps "Upgrade").
//  Branded hero + value props, then StoreKit-backed plan selection, purchase,
//  and the App-Review-required Restore / Terms / Privacy. Prices and trial terms
//  come straight from the loaded `Product`s (localized); no account, no server.
//

import SwiftUI
import StoreKit
import AppCore
import NutritionCore

// TODO: point these at your real, public URLs before submitting to App Review.
// (Terms defaults to Apple's Standard EULA, which is acceptable; Privacy must be yours.)
private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
private let privacyURL = URL(string: "https://example.com/privacy")!

struct PaywallView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var selectedID: String?

    private var sub: SubscriptionManager { container.subscription }
    // Show placeholder plans when StoreKit has no real products loaded — the design
    // preview (`-show-paywall`) and the free-tier gate demo (`-gate`), neither of which
    // loads a live StoreKit configuration under `simctl`.
    private var isPreview: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-show-paywall") || args.contains("-gate")
    }

    var body: some View {
        ZStack {
            photoBackground

            ScrollView {
                VStack(spacing: 28) {
                    hero
                    features
                    plansSection
                }
                .padding(.horizontal, DS.screenPadding)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)

            closeButton
        }
        // Follows the system theme: a light food photo + light cards in light mode,
        // the dark photo + matte dark cards in dark mode (the image asset carries both
        // variants). The scrim flips with it so text stays legible either way.
        .presentationDragIndicator(.visible)
        .task { await sub.refresh() }
        .onChange(of: sub.isSubscribed) { _, nowPro in if nowPro { dismiss() } }
        .onAppear { if selectedID == nil { selectedID = defaultPlanID } }
    }

    /// Full-bleed food photo behind the paywall, deepened with a vertical scrim so the
    /// hero title and footer legal text stay legible while the matte cards pop.
    private var photoBackground: some View {
        GeometryReader { proxy in
            Image("PaywallBackground")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .overlay {
            // A wash in the current scheme's base tone: lightens the light photo so
            // dark text reads, deepens the dark photo so light text reads. Slightly
            // stronger at top and bottom (behind the hero title and footer legal text).
            let wash: Color = scheme == .dark ? .black : .white
            let o: (Double) -> Double = { scheme == .dark ? $0 : $0 * 0.92 }
            LinearGradient(
                stops: [
                    .init(color: wash.opacity(o(0.58)), location: 0.0),
                    .init(color: wash.opacity(o(0.42)), location: 0.32),
                    .init(color: wash.opacity(o(0.55)), location: 0.68),
                    .init(color: wash.opacity(o(0.80)), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            VStack(spacing: 6) {
                Text("CalorieCounter Pro")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("You've used your \(Constants.freeFoodEntryLimit) free entries. Go Pro for unlimited logging.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Features

    private static let perks: [(String, String)] = [
        ("infinity", "Unlimited food logging"),
        ("mic.fill", "Voice, photo & barcode capture"),
        ("heart.fill", "Apple Health sync"),
        ("chart.bar.xaxis", "History, trends & insights"),
        ("lock.fill", "Private — your log stays on your device"),
    ]

    private var features: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.perks, id: \.0) { icon, label in
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.Macro.calories.tint)
                            .frame(width: 26)
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Plans + CTA

    @ViewBuilder private var plansSection: some View {
        let plans = displayPlans
        if plans.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                Text("Plans are unavailable right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            restoreAndLegal
        } else {
            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    planCard(plan)
                }
            }
            ctaButton(for: plans)
            restoreAndLegal
        }
    }

    private func planCard(_ plan: PaywallPlan) -> some View {
        let selected = selectedID == plan.id
        return Button {
            selectedID = plan.id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(selected ? DS.Macro.calories.tint : .secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle().fill(DS.Macro.calories.tint).frame(width: 14, height: 14)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.name).font(.headline)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(DS.Macro.calories.tint.opacity(0.16)))
                                .foregroundStyle(DS.Macro.calories.tint)
                        }
                    }
                    if let trial = plan.trial {
                        Text(trial).font(.caption).foregroundStyle(DS.Macro.calories.tint)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price).font(.headline.monospacedDigit())
                    Text(plan.perPeriod).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .fill(DS.contentFill(scheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                            .stroke(selected ? DS.Macro.calories.tint : DS.cardBorder(scheme, contrast),
                                    lineWidth: selected ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func ctaButton(for plans: [PaywallPlan]) -> some View {
        let plan = plans.first { $0.id == selectedID } ?? plans.first
        let title = plan?.trial != nil ? "Start Free Trial" : "Subscribe"
        return VStack(spacing: 8) {
            Button {
                Task { await purchase(plan) }
            } label: {
                ZStack {
                    if sub.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(title).font(.headline)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Capsule().fill(DS.Macro.calories.linearGradient))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(sub.isPurchasing || plan?.product == nil)

            if let plan, let trial = plan.trial {
                Text("\(trial), then \(plan.price) \(plan.perPeriod). Cancel anytime.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private var restoreAndLegal: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task { await sub.restore(); if sub.isSubscribed { dismiss() } }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DS.Macro.calories.tint)

            Text("Subscriptions auto-renew until cancelled in Settings.")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: termsURL)
                Text("·").foregroundStyle(.tertiary)
                Link("Privacy Policy", destination: privacyURL)
            }
            .font(.caption2)
            .tint(.secondary)
        }
        .padding(.top, 6)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, DS.screenPadding)
                .padding(.top, 12)
            }
            Spacer()
        }
    }

    // MARK: - Plan model

    private func purchase(_ plan: PaywallPlan?) async {
        guard let product = plan?.product else { return }
        if await sub.purchase(product) { dismiss() }
    }

    private var defaultPlanID: String? {
        let plans = displayPlans
        return plans.first(where: { $0.id == SubscriptionManager.yearlyID })?.id ?? plans.first?.id
    }

    /// Real loaded products → display plans; placeholder plans only under `-show-paywall`
    /// (so the design can be previewed without a live StoreKit configuration).
    private var displayPlans: [PaywallPlan] {
        if !sub.products.isEmpty {
            return sub.products.map { product in
                let yearly = product.id == SubscriptionManager.yearlyID
                return PaywallPlan(
                    id: product.id,
                    name: yearly ? "Yearly" : "Monthly",
                    price: product.displayPrice,
                    perPeriod: yearly ? "per year" : "per month",
                    badge: yearly ? sub.yearlySavingsPercent.map { "Save \($0)%" } : nil,
                    trial: sub.trialText(for: product),
                    product: product
                )
            }
        }
        return isPreview ? PaywallPlan.placeholders : []
    }
}

private struct PaywallPlan: Identifiable {
    let id: String
    let name: String
    let price: String
    let perPeriod: String
    let badge: String?
    let trial: String?
    let product: Product?

    /// Illustrative values for design preview only (`-show-paywall`); real prices
    /// always come from App Store Connect.
    static let placeholders: [PaywallPlan] = [
        PaywallPlan(id: SubscriptionManager.monthlyID, name: "Monthly", price: "$5.99",
                    perPeriod: "per month", badge: nil, trial: nil, product: nil),
        PaywallPlan(id: SubscriptionManager.yearlyID, name: "Yearly", price: "$29.99",
                    perPeriod: "per year", badge: "Save 58%", trial: nil, product: nil),
    ]
}
