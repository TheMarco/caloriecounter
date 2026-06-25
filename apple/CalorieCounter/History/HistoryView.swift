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
    @State private var showLogWeight = false

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
            .navigationBarTitleDisplayMode(.inline)
            .task(id: container.dataVersion) {
                let m = model ?? HistoryModel(store: container.store)
                model = m
                await m.load()
            }
            .navigationDestination(item: $selectedDate) { date in
                DayDetailView(date: date)
            }
            .sheet(isPresented: $showLogWeight) {
                LogWeightSheet(currentKg: model?.latestWeightKg, units: container.settings.units)
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
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentWeightText(model))
                                    .font(.title2.weight(.bold))
                                    .contentTransition(.numericText())
                                Text("Current weight").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { showLogWeight = true } label: {
                                Label("Log", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.glass)
                        }
                        WeightChart(points: model.weightPoints,
                                    units: container.settings.units,
                                    window: weightWindow(model))
                            .frame(height: 170)
                    }
                }
                .clearRow()
            } header: {
                sectionHeader("Weight")
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
        .tabBarBottomClearance()
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

    /// The latest measurement in the user's units, e.g. "82.5 kg" (or "—" if none).
    private func currentWeightText(_ model: HistoryModel) -> String {
        guard let kg = model.latestWeightKg else { return "—" }
        let u = container.settings.units
        return String(format: "%.1f %@", u.weightForDisplay(kg: kg), u.weightUnit)
    }

    /// The selected range as a date span, so the weight chart's x-axis covers the
    /// whole window even when measurements are sparse.
    private func weightWindow(_ model: HistoryModel) -> ClosedRange<Date>? {
        guard let first = model.days.first?.date, let last = model.days.last?.date,
              let lo = LocalDate.date(from: first), let hi = LocalDate.date(from: last), lo < hi else { return nil }
        return lo...hi
    }
}
