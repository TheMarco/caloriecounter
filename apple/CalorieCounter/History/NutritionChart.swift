//
//  NutritionChart.swift
//  Swift Charts daily bars painted in the macro's gradient, with a dashed target
//  rule. Data comes from HistoryModel.series (bucketing + over-target flagging are
//  unit-tested).
//

import SwiftUI
import Charts
import AppCore

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

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Day", shortLabel(point.date)),
                    y: .value(unit.capitalized, point.value),
                    width: .ratio(0.6)
                )
                .foregroundStyle(point.isOverTarget
                                 ? AnyShapeStyle(Color.red.gradient)
                                 : AnyShapeStyle(macro.linearGradient))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: min(max(points.count, 1), 14))
        .chartYAxis { AxisMarks(position: .leading) }
        .overlay {
            if points.allSatisfy({ $0.value == 0 }) {
                Text("No data in this range yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func shortLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return key }
        return "\(m)/\(d)"
    }
}
