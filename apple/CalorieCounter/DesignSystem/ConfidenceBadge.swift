//
//  ConfidenceBadge.swift
//  Surfaces an entry's provenance — Measured / Estimated / Adjusted — so an AI
//  guess never masquerades as a label value. The Measured/Estimated/Adjusted rule
//  itself lives in the pure, unit-tested `ConfidenceDisplay` (NutritionCore); this
//  view only paints it. Two styles: a compact pill, and a one-line "source row".
//

import SwiftUI
import NutritionCore

struct ConfidenceBadge: View {
    let confidence: NutritionConfidence?
    var style: Style = .pill
    /// Optional capture-method phrasing for the source row, e.g. "Photo estimate".
    var sourceLabel: String? = nil

    enum Style { case pill, sourceRow }

    private var display: ConfidenceDisplay { .from(confidence) }

    /// View-layer tint for each provenance kind (the pure model stays color-free).
    private var tint: Color {
        switch display.kind {
        case .measured:  return DS.Macro.calories.tint   // a calm "verified" green
        case .adjusted:  return .accentColor
        case .estimated: return .secondary
        }
    }

    /// The honesty note shown after the source on the one-line row.
    private var note: String {
        switch display.kind {
        case .measured:  return "exact numbers"
        case .adjusted:  return "your saved correction"
        case .estimated: return "an estimate — about, not exact"
        }
    }

    private var accessibilityText: String {
        let lead = sourceLabel ?? "\(display.title) nutrition"
        return "\(lead), \(note)"
    }

    var body: some View {
        switch style {
        case .pill:      pill
        case .sourceRow: sourceRow
        }
    }

    private var pill: some View {
        HStack(spacing: 5) {
            Image(systemName: display.symbolName)
                .font(.caption2.weight(.bold))
            Text(display.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)   // never collapse to stacked letters
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var sourceRow: some View {
        // A tinted symbol + one wrapping Text — the single Text wraps cleanly at
        // large accessibility sizes (a multi-column HStack would overflow).
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: display.symbolName)
                .foregroundStyle(tint)
            Text("\(sourceLabel ?? display.title)  ·  \(note)")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

#Preview("Pills", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 12) {
        ConfidenceBadge(confidence: .barcode)
        ConfidenceBadge(confidence: .userEdited)
        ConfidenceBadge(confidence: .estimated)
        Divider()
        ConfidenceBadge(confidence: .barcode, style: .sourceRow, sourceLabel: "Barcode")
        ConfidenceBadge(confidence: .userEdited, style: .sourceRow)
        ConfidenceBadge(confidence: .estimated, style: .sourceRow, sourceLabel: "Photo estimate")
    }
    .padding()
}
