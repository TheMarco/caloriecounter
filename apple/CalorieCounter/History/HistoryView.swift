//
//  HistoryView.swift
//  Range selector (7/30/90), per-macro Swift Chart, and a month calendar over the
//  app backdrop. Data via HistoryModel; tapping a calendar day opens detail.
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
            ZStack {
                AppBackground()
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
                .clearRow()
            }

            Section {
                SoftCard {
                    VStack(spacing: 14) {
                        Picker("Macro", selection: $macro) {
                            ForEach(MacroKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        NutritionChart(
                            points: model.series(macro, targets: container.settings.targets),
                            target: macro.target(in: container.settings.targets),
                            unit: macro.unit,
                            macro: macro.ds
                        )
                        .frame(height: 230)
                    }
                }
                .clearRow()
            } header: {
                sectionHeader("Trends")
            }

            Section {
                SoftCard {
                    CalendarView(datesWithEntries: model.datesWithEntries) { date in
                        selectedDate = date
                    }
                }
                .clearRow()
            } header: {
                sectionHeader("This Month")
            }
        }
        .listStyle(.plain)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await model.load() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.leading, 4)
    }
}
