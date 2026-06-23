//
//  TodayView.swift
//  The main tracking dashboard: macro card, exercise offset, and the day's entry
//  list, with the Liquid Glass quick-add cluster anchored at the bottom. Reads
//  through TodayModel (over the NutritionStoring seam); no SwiftUI @Query.
//

import SwiftUI
import AppCore
import NutritionCore

struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: TodayModel?
    @State private var activeInput: InputMethod?
    @State private var editingEntry: Entry?
    @State private var editingOffset = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    dashboard(model)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Today")
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaInset(edge: .bottom) {
                QuickAddBar { activeInput = $0 }
            }
            .task {
                let m = model ?? TodayModel(store: container.store)
                model = m
                await m.load()
            }
            .sheet(item: $activeInput) { method in
                InputFlowView(method: method) {
                    Task { await model?.load() }
                }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry) {
                    Task { await model?.load() }
                }
            }
            .sheet(isPresented: $editingOffset) {
                if let model {
                    CalorieOffsetSheet(value: model.offset) { newValue in
                        Task { await model.updateOffset(newValue) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dashboard(_ model: TodayModel) -> some View {
        List {
            Section {
                TabbedTotalCard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                CalorieOffsetView(offset: model.offset) { editingOffset = true }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section("Today's food") {
                if model.entries.isEmpty {
                    Text("No entries yet — add your first food below.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(model.entries) { entry in
                        Button { editingEntry = entry } label: { EntryRow(entry: entry) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { model.entries[$0].id }
                        Task { for id in ids { await model.deleteEntry(id: id) } }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }
}
