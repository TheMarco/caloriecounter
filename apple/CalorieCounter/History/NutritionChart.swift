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

    private var isEmpty: Bool { points.allSatisfy { $0.value == 0 } }

    var body: some View {
        Chart {
            ForEach(points) { point in
                if let date = LocalDate.date(from: point.date) {
                    BarMark(
                        x: .value("Day", date, unit: .day),
                        y: .value(unit.capitalized, point.value)
                    )
                    .foregroundStyle(point.isOverTarget
                                     ? AnyShapeStyle(DS.over.gradient)
                                     : AnyShapeStyle(macro.linearGradient))
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
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .overlay {
            if isEmpty {
                Text("No data in this range yet")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
