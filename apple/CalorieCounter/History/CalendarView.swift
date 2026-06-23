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
    let onSelect: (String) -> Void

    private let month: CalendarMonth?
    private let today: String
    private let weekdaySymbols: [String]

    init(datesWithEntries: Set<String>, onSelect: @escaping (String) -> Void) {
        self.datesWithEntries = datesWithEntries
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
        let isToday = key == today
        Button {
            onSelect(key)
        } label: {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                Circle()
                    .fill(hasEntries ? Color.accentColor : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isToday ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day)\(hasEntries ? ", has entries" : "")")
    }
}
