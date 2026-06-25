//
//  WeightChart.swift
//  A line chart of body weight over the selected range. Values are stored in
//  kilograms and converted to the user's unit system for display. The y-axis
//  auto-scales to the data with padding (it does not start at zero), and the
//  x-axis spans the whole selected window so sparse (e.g. weekly) measurements
//  still sit on a proper date axis.
//

import SwiftUI
import Charts
import AppCore
import NutritionCore

struct WeightChart: View {
    let points: [WeightPoint]
    let units: UnitSystem
    var window: ClosedRange<Date>? = nil

    private var values: [Double] { points.map { units.weightForDisplay(kg: $0.weightKg) } }

    /// Padded y-range around the data so small changes are visible (never 0-based).
    private var yDomain: ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        if lo == hi { return (lo - 2)...(hi + 2) }
        let pad = max(1, (hi - lo) * 0.25)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                if let date = LocalDate.date(from: p.date) {
                    let value = units.weightForDisplay(kg: p.weightKg)
                    LineMark(x: .value("Day", date, unit: .day), y: .value("Weight", value))
                        // Linear, not catmullRom/cardinal: a smooth spline overshoots
                        // on a steep change between sparse weigh-ins and draws the line
                        // outside the plot frame. Straight segments are also more honest.
                        .interpolationMethod(.linear)
                        .foregroundStyle(DS.Macro.carbs.linearGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Day", date, unit: .day), y: .value("Weight", value))
                        .foregroundStyle(DS.Macro.carbs.tint)
                        .symbolSize(34)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            // Explicit stride (~4 labels), not .automatic: automatic picks daily marks
            // for a short range and the rightmost one truncates to "…" against the
            // padded domain edge. Strided marks land on whole days, inset from the edge.
            AxisMarks(values: .stride(by: .day, count: labelStride)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .overlay {
            if points.isEmpty {
                Text("No weight logged yet").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    /// Span the full selected window if given, else the data's own date span — padded
    /// a little on each end so a weigh-in on the first/last day isn't pinned to (or
    /// clipped at) the plot edge.
    private var xDomain: ClosedRange<Date> {
        let base: ClosedRange<Date>
        if let window {
            base = window
        } else {
            let dates = points.compactMap { LocalDate.date(from: $0.date) }
            if let lo = dates.min(), let hi = dates.max(), lo < hi {
                base = lo...hi
            } else {
                let now = Date()
                return now.addingTimeInterval(-86_400)...now
            }
        }
        let pad = base.upperBound.timeIntervalSince(base.lowerBound) * 0.06
        return base.lowerBound.addingTimeInterval(-pad)...base.upperBound.addingTimeInterval(pad)
    }

    /// Day interval between x-axis labels — ~4 across the range, so they stay sparse
    /// and fully legible (no crowding or truncation) at any window length.
    private var labelStride: Int {
        let days = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound) / 86_400
        return max(1, Int((days / 4).rounded(.up)))
    }
}
