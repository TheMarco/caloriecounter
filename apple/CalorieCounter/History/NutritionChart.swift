//
//  NutritionChart.swift
//  Swift Charts daily bars colored vs the target, with a dashed target rule and a
//  tap callout. Data comes from HistoryModel.series (date bucketing + over-target
//  flagging are unit-tested).
//

import SwiftUI
import Charts
import AppCore

struct NutritionChart: View {
    let points: [MacroSeriesPoint]
    let target: Double
    let unit: String

    @State private var selectedLabel: String?

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Day", shortLabel(point.date)),
                    y: .value(unit.capitalized, point.value)
                )
                .foregroundStyle(point.isOverTarget ? Color.red : Color.accentColor)
                .cornerRadius(4)
            }
            if target > 0 {
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target \(Int(target)) \(unit)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: min(points.count, 14))
        .chartYAxis { AxisMarks(position: .leading) }
        .overlay {
            if points.allSatisfy({ $0.value == 0 }) {
                Text("No data in this range yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    /// "2026-06-05" → "6/5".
    private func shortLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return key }
        return "\(m)/\(d)"
    }
}
