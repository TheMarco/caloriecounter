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
                                       units: container.settings.units)
            }
        }
    }

    private func content(_ model: TextInputModel) -> some View {
        @Bindable var model = model
        return Form {
            Section {
                TextField("e.g. “2 eggs and toast”", text: $model.query, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.search)
                    .onSubmit { submit(model) }
                    .onChange(of: model.query) { _, _ in
                        Task { await model.updateSuggestions() }
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
