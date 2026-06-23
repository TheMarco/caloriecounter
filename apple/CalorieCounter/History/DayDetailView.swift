//
//  DayDetailView.swift
//  Entries, totals, and offset for a historical date. Reuses TodayModel (which is
//  date-parameterized) so the same tested aggregation drives it.
//

import SwiftUI
import AppCore
import NutritionCore

struct DayDetailView: View {
    @Environment(AppContainer.self) private var container
    let date: String

    @State private var model: TodayModel?

    var body: some View {
        Group {
            if let model {
                List {
                    Section {
                        TabbedTotalCard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    if model.offset > 0 {
                        Section {
                            LabeledContent("Exercise / Adjustment", value: "−\(Int(model.offset)) kcal")
                        }
                    }
                    Section("Food") {
                        if model.entries.isEmpty {
                            Text("No entries logged this day.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(model.entries) { EntryRow(entry: $0) }
                                .onDelete { offsets in
                                    let ids = offsets.map { model.entries[$0].id }
                                    Task { for id in ids { await model.deleteEntry(id: id) } }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(prettyDate)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let m = model ?? TodayModel(store: container.store, date: date)
            model = m
            await m.load()
        }
    }

    private var prettyDate: String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return date }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        guard let d = Calendar.current.date(from: components) else { return date }
        return d.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
