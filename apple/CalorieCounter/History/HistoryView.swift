//
//  HistoryView.swift
//  Range selector (7/30/90), per-macro Swift Chart, and a month calendar. Data
//  via HistoryModel over store.dailyTotals; tapping a calendar day opens detail.
//

import SwiftUI
import AppCore
import NutritionCore

struct HistoryView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: HistoryModel?
    @State private var macro: MacroKind = .calories
    @State private var selectedDate: String?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("History")
            .task {
                let m = model ?? HistoryModel(store: container.store)
                model = m
                await m.load()
            }
            .navigationDestination(item: $selectedDate) { date in
                DayDetailView(date: date)
            }
        }
    }

    private func content(_ model: HistoryModel) -> some View {
        @Bindable var model = model
        return List {
            Section {
                Picker("Range", selection: $model.range) {
                    ForEach(DateRange.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.range) { _, _ in Task { await model.load() } }
            }

            Section {
                Picker("Macro", selection: $macro) {
                    ForEach(MacroKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                NutritionChart(
                    points: model.series(macro, targets: container.settings.targets),
                    target: macro.target(in: container.settings.targets),
                    unit: macro.unit
                )
                .frame(height: 240)
                .padding(.vertical, 8)
            }

            Section("This month") {
                CalendarView(datesWithEntries: model.datesWithEntries) { date in
                    selectedDate = date
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }
}
