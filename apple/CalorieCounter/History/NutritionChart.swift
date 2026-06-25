//
//  NutritionChart.swift
//  Swift Charts daily bars painted in the macro's gradient, with a dashed target
//  rule. Data comes from HistoryModel.series (bucketing + over-target flagging are
//  unit-tested). The x-axis is a real date scale so the WHOLE selected range fits
//  in view (auto-strided labels) — no hidden horizontal scroll.
//

import SwiftUI
import Charts
import AppCore
import NutritionCore

/// Maps the model's MacroKind to the design-system palette.
extension MacroKind {
    var ds: DS.Macro {
        switch self {
        case .calories: return .calories
        case .protein: return .protein
        case .carbs: return .carbs
        case .fat: return .fat
        }
    }
}

struct NutritionChart: View {
    let points: [MacroSeriesPoint]
    let target: Double
    let unit: String
    var macro: DS.Macro = .calories
    /// A rich summary for a day key (kcal + macros) shown when a bar is selected.
    var daySummary: (String) -> String? = { _ in nil }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var selectedDate: Date?

    private var isEmpty: Bool { points.allSatisfy { $0.value == 0 } }

    /// Show ~6 date labels at most, whatever the range — so they never crowd into
    /// "5…" the way per-bar labels did. (Charts ignores `desiredCount` on a dense
    /// daily scale, so stride explicitly.)
    private var labelStride: Int { max(1, Int((Double(points.count) / 6).rounded(.up))) }

    private var selectedKey: String? { selectedDate.map { LocalDate.key(for: $0) } }
    private var selectedPoint: MacroSeriesPoint? {
        guard let key = selectedKey else { return nil }
        return points.first { $0.date == key }
    }

    /// A bar's style — muted when another bar is the focus, so the selection leads.
    private func barStyle(_ point: MacroSeriesPoint) -> AnyShapeStyle {
        let base = point.isOverTarget ? AnyShapeStyle(DS.over.gradient) : AnyShapeStyle(macro.linearGradient)
        guard let key = selectedKey, key != point.date else { return base }
        return AnyShapeStyle(macro.tint.opacity(0.22))
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                if let date = LocalDate.date(from: point.date) {
                    BarMark(
                        x: .value("Day", date, unit: .day),
                        y: .value(unit.capitalized, point.value)
                    )
                    .foregroundStyle(barStyle(point))
                    .cornerRadius(3)
                }
            }
            if target > 0 {
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(Int(target)) \(unit)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
            }
            if let sp = selectedPoint, let date = LocalDate.date(from: sp.date) {
                RuleMark(x: .value("Selected", date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit, y: .disabled)) {
                        dayCallout(sp)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelStride)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .overlay {
            if isEmpty {
                Text("No data in this range yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartSummary)
    }

    /// The selected day's totals, shown as a small callout above the bar.
    private func dayCallout(_ point: MacroSeriesPoint) -> some View {
        let summary = daySummary(point.date) ?? "\(Int(point.value)) \(unit)"
        return Text(summary)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(DS.contentFill(scheme)))
            .overlay(Capsule().stroke(DS.cardBorder(scheme, contrast), lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.12), radius: 6, y: 2)
            .fixedSize()
    }

    /// One-line VoiceOver summary of the whole chart.
    private var chartSummary: String {
        let logged = points.filter { $0.value > 0 }
        guard !logged.isEmpty else { return "\(unit) chart, no data in this range yet" }
        let avg = Int((logged.reduce(0) { $0 + $1.value } / Double(logged.count)).rounded())
        let lo = Int((logged.map(\.value).min() ?? 0).rounded())
        let hi = Int((logged.map(\.value).max() ?? 0).rounded())
        return "\(points.count)-day \(unit.lowercased()) chart. Average \(avg) \(unit), range \(lo) to \(hi)."
    }
}
