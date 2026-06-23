//
//  DayDetailView.swift
//  Entries, totals, and offset for a historical date — the same hero rings and
//  glass cards as Today. Reuses the date-parameterized TodayModel.
//

import SwiftUI
import AppCore
import NutritionCore

struct DayDetailView: View {
    @Environment(AppContainer.self) private var container
    let date: String

    @State private var model: TodayModel?

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                List {
                    Section {
                        MacroDashboard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                            .padding(.top, 4)
                            .clearRow()
                    }
                    if model.offset > 0 {
                        Section {
                            OffsetChip(offset: model.offset) {}
                                .disabled(true)
                                .clearRow()
                        }
                    }
                    Section {
                        if model.entries.isEmpty {
                            Text("No entries logged this day.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .clearRow()
                        } else {
                            ForEach(model.entries) { EntryCard(entry: $0).clearRow() }
                                .onDelete { offsets in
                                    let ids = offsets.map { model.entries[$0].id }
                                    Task { for id in ids { await model.deleteEntry(id: id) } }
                                }
                        }
                    } header: {
                        if !model.entries.isEmpty {
                            Text("Food").font(.headline).textCase(nil).padding(.leading, 4)
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(10)
                .scrollContentBackground(.hidden)
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
