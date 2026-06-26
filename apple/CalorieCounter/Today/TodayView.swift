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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    /// Shows a transient undo toast (hosted by the dock container).
    var presentUndo: (String, @escaping () -> Void) -> Void = { _, _ in }
    /// Opens Settings (the top-right gear).
    var onOpenSettings: () -> Void = {}
    /// The entry just logged (briefly haloed as it lands).
    var justLoggedId: String? = nil

    @State private var model: TodayModel?
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsGearButton(action: onOpenSettings)
                }
                .sharedBackgroundVisibility(.hidden)   // no glass capsule — a quiet affordance
            }
            .task(id: container.dataVersion) {
                let m = model ?? TodayModel(store: container.store)
                model = m
                await container.bootstrap()   // seeds demo data in -demo mode (idempotent)
                await m.load()
                latestWeightKg = (try? await container.store.latestWeight())?.weightKg
                workoutOffers = await container.pendingWorkoutOffers()
            }
            .onChange(of: scenePhase) { _, phase in
                // Returning to the app after a workout: re-check for new offers, since
                // a foreground resume doesn't bump dataVersion on its own.
                if phase == .active {
                    Task { workoutOffers = await container.pendingWorkoutOffers() }
                }
            }
            .fullScreenCover(isPresented: $showWizard) {
                SetupWizardView(allowsCancel: true) {}
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
                MacroDashboard(totals: model.totals, targets: container.settings.targets, offset: model.offset)
                    .padding(.top, 34)
                    .padding(.bottom, 12)
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
            if !model.usuals.isEmpty {
                Section {
                    usualsRow(model)
                } header: {
                    Text("Your Usuals")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .padding(.leading, 4)
                }
            }
            Section {
                if model.entries.isEmpty {
                    EmptyDayCard().clearRow()
                } else {
                    ForEach(model.entries) { entry in
                        Button { editingEntry = entry } label: { EntryCard(entry: entry) }
                            .buttonStyle(.plain)
                            .justLoggedHighlight(entry.id == justLoggedId)
                            .clearRow()
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { editingEntry = entry } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(DS.Macro.carbs.tint)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteWithUndo(entry, in: model) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await model.load() }
        .tabBarBottomClearance()
    }

    // MARK: - Usuals

    /// One-tap re-log of frequently-eaten foods.
    private func usualsRow(_ model: TodayModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.usuals) { usual in
                    Button { relogUsual(usual, in: model) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: usual.method.systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(usual.food).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text("\(Int(usual.kcal))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.Macro.calories.tint)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(DS.contentFill(scheme)))
                        .overlay(Capsule().stroke(DS.cardBorder(scheme, contrast), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(usual.food), \(Int(usual.kcal)) calories")
                }
            }
            .padding(.horizontal, DS.screenPadding)
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Undo plumbing (the toast itself is hosted by the dock container)

    /// Delete an entry and offer to restore it.
    private func deleteWithUndo(_ entry: Entry, in model: TodayModel) {
        Task {
            await model.deleteEntry(id: entry.id)
            await container.healthDeleteFood(id: entry.id)
            container.dataDidChange()
            presentUndo("Deleted") {
                Task {
                    await model.restore(entry)
                    await container.healthSyncFood(entry)
                    container.dataDidChange()
                }
            }
        }
    }

    /// Re-log a usual and offer to undo it.
    private func relogUsual(_ usual: Entry, in model: TodayModel) {
        guard container.beginFoodLog() else { return }   // gate: a relog is a new food entry
        Task {
            let fresh = await model.relog(usual)
            container.didLogFood()
            await container.healthSyncFood(fresh)
            container.dataDidChange()
            presentUndo("Logged") {
                Task {
                    await model.deleteEntry(id: fresh.id)
                    await container.healthDeleteFood(id: fresh.id)
                    container.dataDidChange()
                }
            }
        }
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
