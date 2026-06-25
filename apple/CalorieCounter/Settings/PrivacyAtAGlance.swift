//
//  PrivacyAtAGlance.swift
//  A one-glance picture of the privacy model: a sealed "phone" holding everything
//  personal, with a single, clearly-labeled outflow — only the food text/photo you
//  submit, anonymized — to the cloud estimator. Reinforces the About copy visually.
//

import SwiftUI

struct PrivacyAtAGlance: View {
    @Environment(\.colorScheme) private var scheme

    private let onDevice = [
        "Your food log & corrections",
        "Weights",
        "Daily targets",
        "Settings",
    ]

    private var green: Color { DS.Macro.calories.tint }

    var body: some View {
        VStack(spacing: 8) {
            // The sealed phone — everything personal lives here and never leaves.
            VStack(alignment: .leading, spacing: 9) {
                Label("On this phone", systemImage: "iphone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(green)
                ForEach(onDevice, id: \.self) { item in
                    Label {
                        Text(item).font(.footnote)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(green)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(green.opacity(scheme == .dark ? 0.12 : 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(green.opacity(0.45), lineWidth: 1))
            }

            // The single outflow — labeled and anonymized.
            VStack(spacing: 1) {
                Image(systemName: "arrow.down").font(.caption.weight(.semibold))
                Text("only the food text or photo you submit")
                    .font(.caption2.weight(.medium))
                Text("no account · nothing that identifies you · not used for training")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 2)

            // The cloud endpoint.
            Label("OpenAI estimates the nutrition", systemImage: "cloud")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DS.contentFill(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.cardBorder(scheme, .standard), lineWidth: 1))
                }

            // Two small footnotes for the remaining nuances.
            HStack(spacing: 14) {
                footnote("mic.fill", "Voice is transcribed on-device")
                footnote("heart.text.square.fill", "Health is optional")
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("What stays on device. Your food log, corrections, weights, targets, and settings stay on this phone. Only the food text or photo you submit is sent to OpenAI to estimate nutrition — with no account and nothing that identifies you. Voice is transcribed on-device, then handled like typed text; Apple Health is optional.")
    }

    private func footnote(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
