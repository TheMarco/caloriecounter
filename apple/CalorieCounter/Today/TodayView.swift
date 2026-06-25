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
    @State private var latestWeightKg: Double?
    @State private var showWizard = false
    @State private var nudgeDismissed = false
    @State private var workoutOffers: [WorkoutSample] = []

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
            .navigationBarTitleDisplayMode(.inline)
            .task(id: container.dataVersion) {
                let m = model ?? TodayModel(store: container.store)
                model = m
                await container.bootstrap()   // seeds demo data in -demo mode (idempotent)
                await m.load()
                latestWeightKg = (try? await container.store.latestWeight())?.weightKg
                workoutOffers = await container.pendingWorkoutOffers()
            }
            .fullScreenCover(isPresented: $showWizard) {
                SetupWizardView(allowsCancel: true) {}
            }
            .sheet(item: $activeInput) { method in
                InputFlowView(method: method) { container.dataDidChange() }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntryView(entry: entry) { container.dataDidChange() }
            }
            .sheet(isPresented: $editingOffset) {
                if let model {
                    CalorieOffsetSheet(value: model.offset) { newValue in
                        Task { await model.updateOffset(newValue); container.dataDidChange() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dashboard(_ model: TodayModel) -> some View {
        List {
            if showNudge {
                Section {
                    weightDriftBanner.clearRow()
                }
            }
            Section {
                QuickAddBar { activeInput = $0 }
                    .padding(.bottom, 8)
                    .clearRow()
            }
            Section {
                MacroDashboard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                    .padding(.top, 24)
                    .clearRow()
            }
            Section {
                OffsetChip(offset: model.offset) { editingOffset = true }
                    .clearRow()
            }
            ForEach(workoutOffers) { offer in
                Section {
                    workoutOfferBanner(offer).clearRow()
                }
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
                        Task {
                            for id in ids { await model.deleteEntry(id: id); await container.healthDeleteFood(id: id) }
                            container.dataDidChange()
                        }
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
        .tabBarBottomClearance()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await model.load() }
    }

    // MARK: - Workout offset offer

    private func workoutOfferBanner(_ offer: WorkoutSample) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Workout detected", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                Text("You burned about \(Int(offer.kcal)) kcal in a \(offer.durationMinutes)-min \(offer.activityName). Add it to your calorie offset?")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Add \(Int(offer.kcal)) kcal") {
                        Task { await container.applyWorkoutOffset(offer); container.dataDidChange() }
                    }
                    .buttonStyle(.glass).tint(DS.Macro.calories.tint)
                    Button("Not now") {
                        container.dismissWorkoutOffer(offer)
                        workoutOffers.removeAll { $0.id == offer.id }
                    }
                    .buttonStyle(.glass)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Weight-drift nudge

    private var weightDrift: Double? {
        WeightDrift.driftKg(plan: container.settings.savedProfile?.weightKg, latest: latestWeightKg)
    }
    private var showNudge: Bool {
        !nudgeDismissed && container.settings.savedProfile != nil && WeightDrift.isSignificant(weightDrift)
    }
    private var nudgeMessage: String {
        guard let drift = weightDrift else { return "" }
        let u = container.settings.units
        let amount = abs(u.weightForDisplay(kg: drift))
        let dir = drift < 0 ? "down" : "up"
        return String(format: "Your weight is about %.0f %@ %@ from when you set your plan.", amount, u.weightUnit, dir)
    }

    private var weightDriftBanner: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Refresh your plan?", systemImage: "scalemass")
                    .font(.subheadline.weight(.semibold))
                Text("\(nudgeMessage) You can refresh your targets to match whenever you're ready.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Refresh plan") { showWizard = true }
                        .buttonStyle(.glass).tint(DS.Macro.calories.tint)
                    Button("Not now") { nudgeDismissed = true }
                        .buttonStyle(.glass)
                }
                .font(.subheadline)
            }
        }
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
