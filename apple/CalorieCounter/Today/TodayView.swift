//
//  TodayView.swift
//  The main tracking dashboard: the hero macro rings, the exercise offset, and the
//  day's food as floating glass cards, over the app backdrop. Reads through
//  TodayModel (over the NutritionStoring seam); no SwiftUI @Query.
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
            ZStack {
                AppBackground()
                if let model {
                    dashboard(model)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Today")
            .safeAreaInset(edge: .bottom) {
                QuickAddBar { activeInput = $0 }
            }
            .task {
                let m = model ?? TodayModel(store: container.store)
                model = m
                await container.bootstrap()   // seeds demo data in -demo mode (idempotent)
                await m.load()
            }
            .sheet(item: $activeInput) { method in
                InputFlowView(method: method) { Task { await model?.load() } }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry) { Task { await model?.load() } }
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
                MacroDashboard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                    .padding(.top, 4)
                    .clearRow()
            }
            Section {
                OffsetChip(offset: model.offset) { editingOffset = true }
                    .clearRow()
            }
            Section {
                if model.entries.isEmpty {
                    EmptyDayCard().clearRow()
                } else {
                    ForEach(model.entries) { entry in
                        Button { editingEntry = entry } label: { EntryCard(entry: entry) }
                            .buttonStyle(.plain)
                            .clearRow()
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { model.entries[$0].id }
                        Task { for id in ids { await model.deleteEntry(id: id) } }
                    }
                }
            } header: {
                if !model.entries.isEmpty {
                    Text("Today's Food")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .padding(.leading, 4)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await model.load() }
    }
}

extension View {
    /// Standard transparent, edge-to-edge list row used across the redesigned screens.
    func clearRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 5, leading: DS.screenPadding, bottom: 5, trailing: DS.screenPadding))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
