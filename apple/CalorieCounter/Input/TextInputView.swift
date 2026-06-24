//
//  TextInputView.swift
//  Type a food description (on-device Foundation Models parse), with autocomplete
//  from previously-eaten foods. Works fully on the simulator (heuristic parser
//  when FM is unavailable).
//

import SwiftUI
import AppCore
import NutritionCore

struct TextInputView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openURL) private var openURL
    let onParsed: (ParsedFood) -> Void

    @State private var model: TextInputModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Type Food")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = TextInputModel(store: container.store,
                                       parser: container.foodParser,
                                       foodSearch: container.foodSearch,
                                       foodDatabase: container.foodDatabase,
                                       units: container.settings.units)
            }
        }
    }

    private func content(_ model: TextInputModel) -> some View {
        @Bindable var model = model
        return Form {
            if container.shouldSuggestEnablingAI {
                Section { aiHint }
            }
            Section {
                TextField("e.g. “2 eggs and toast”", text: $model.query)
                    .submitLabel(.search)
                    .onSubmit { submit(model) }
                    .onChange(of: model.query) { _, _ in
                        Task { await model.updateSuggestions() }
                        Task { await model.searchProducts() }
                        Task { await model.searchDatabase() }
                    }
                Button {
                    submit(model)
                } label: {
                    if model.isParsing {
                        HStack { ProgressView(); Text("Analyzing…") }
                    } else {
                        Label("Analyze", systemImage: "sparkles")
                    }
                }
                .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.isParsing)
            }

            if !model.dbMatches.isEmpty {
                Section {
                    ForEach(Array(model.dbMatches.enumerated()), id: \.offset) { _, match in
                        Button {
                            onParsed(match)
                        } label: {
                            matchRow(match, icon: "fork.knife")
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Foods")
                } footer: {
                    Text("From the on-device USDA database. Tap to use measured nutrition.")
                }
            }

            if !model.productMatches.isEmpty {
                Section {
                    ForEach(Array(model.productMatches.enumerated()), id: \.offset) { _, match in
                        Button {
                            onParsed(match)
                        } label: {
                            matchRow(match, icon: "barcode.viewfinder")
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Product matches")
                } footer: {
                    Text("From the OpenFoodFacts database. Tap to use the label values.")
                }
            }

            if !model.suggestions.isEmpty {
                Section("Recent foods") {
                    ForEach(model.suggestions) { entry in
                        Button {
                            onParsed(ParsedFood(entry: entry))
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .alert("Couldn’t analyze", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// A quiet, dismissible nudge shown only on a capable device where Apple
    /// Intelligence is switched off — it's what powers breaking down meals we don't
    /// already recognize.
    private var aiHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Turn on Apple Intelligence for smarter results", systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
            Text("It lets the app break down meals it doesn’t recognize into ingredients. Find it in Settings → Apple Intelligence & Siri.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                Spacer()
                Button("Not now") { container.settings.aiNudgeDismissed = true }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func matchRow(_ match: ParsedFood, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.food)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(matchSubtitle(match))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(match.kcal.rounded())) kcal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// "1 serving · 4 items · P 12 · C 30 · F 8" — a compact line for a match (the
    /// item count appears when the match carries a recipe breakdown).
    private func matchSubtitle(_ match: ParsedFood) -> String {
        let qty = match.quantity == match.quantity.rounded()
            ? String(Int(match.quantity)) : String(format: "%.1f", match.quantity)
        var parts = ["\(qty) \(match.unit)"]
        if let n = match.components?.count, n > 1 { parts.append("\(n) items") }
        parts.append("P \(Int(match.protein.rounded()))")
        parts.append("C \(Int(match.carbs.rounded()))")
        parts.append("F \(Int(match.fat.rounded()))")
        return parts.joined(separator: " · ")
    }

    private func submit(_ model: TextInputModel) {
        Task {
            do {
                onParsed(try await model.parse())
            } catch {
                errorMessage = "We couldn’t understand that. Try rephrasing the food and amount."
            }
        }
    }
}
