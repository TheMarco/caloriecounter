//
//  CalendarView.swift
//  Current-month grid with a dot on days that have logged food; tapping a day
//  opens its detail. Layout (leading blanks, day count) comes from the
//  unit-tested CalendarMonth.
//

import SwiftUI
import AppCore
import NutritionCore

struct CalendarView: View {
    let datesWithEntries: Set<String>
    /// Provenance per day → a subtle filled (measured) vs hollow (estimated) dot.
    var provenance: (String) -> DayProvenance = { _ in .none }
    let onSelect: (String) -> Void

    private let month: CalendarMonth?
    private let today: String
    private let weekdaySymbols: [String]

    init(datesWithEntries: Set<String>,
         provenance: @escaping (String) -> DayProvenance = { _ in .none },
         onSelect: @escaping (String) -> Void) {
        self.datesWithEntries = datesWithEntries
        self.provenance = provenance
        self.onSelect = onSelect
        self.today = LocalDate.today()
        let parts = today.split(separator: "-").compactMap { Int($0) }
        self.month = parts.count == 3 ? CalendarMonth(year: parts[0], month: parts[1]) : nil
        let cal = Calendar.current
        // Order short weekday symbols starting at the calendar's firstWeekday.
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        self.weekdaySymbols = Array(symbols[start...] + symbols[..<start])
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(.caption2).foregroundStyle(.secondary)
                }
                if let month {
                    ForEach(0..<month.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 38) }
                    ForEach(1...month.dayCount, id: \.self) { day in
                        dayCell(month.dateKey(day: day), day: day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ key: String, day: Int) -> some View {
        let hasEntries = datesWithEntries.contains(key)
        let prov = provenance(key)
        let isToday = key == today
        Button {
            onSelect(key)
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background {
                        if isToday {
                            Circle().fill(DS.Macro.calories.linearGradient)
                                .shadow(color: DS.Macro.calories.tint.opacity(0.5), radius: 6)
                        }
                    }
                provenanceDot(prov, hasEntries: hasEntries)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day)\(accessibilitySuffix(prov, hasEntries: hasEntries))")
    }

    /// A subtle, judgment-free provenance mark: a solid dot for measured days, a
    /// softer dot for mixed, a hollow ring for estimate-only days.
    @ViewBuilder
    private func provenanceDot(_ prov: DayProvenance, hasEntries: Bool) -> some View {
        let tint = DS.Macro.calories.tint
        switch prov {
        case .allExact:
            Circle().fill(tint).frame(width: 5, height: 5)
        case .mixed:
            Circle().fill(tint.opacity(0.45)).frame(width: 5, height: 5)
        case .estimated:
            Circle().strokeBorder(tint.opacity(0.75), lineWidth: 1).frame(width: 5, height: 5)
        case .none:
            Circle().fill(hasEntries ? tint : .clear).frame(width: 5, height: 5)
        }
    }

    private func accessibilitySuffix(_ prov: DayProvenance, hasEntries: Bool) -> String {
        switch prov {
        case .allExact:  return ", measured entries"
        case .mixed:     return ", measured and estimated entries"
        case .estimated: return ", estimated entries"
        case .none:      return hasEntries ? ", has entries" : ""
        }
    }
}
