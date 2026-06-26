//
//  HelpView.swift
//  A comprehensive in-app guide, reached from the top-left "?" on Today and History
//  (the left-hand companion to the Settings gear). Matte cards over the same adaptive
//  food-photo backdrop as the paywall, so Help feels of a piece with the premium
//  surfaces — calm and readable, every feature explained without leaving the app.
//

import SwiftUI
import AppCore
import NutritionCore

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FoodPhotoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Everything you need to track what you eat — by voice, photo, barcode, or text — with your diary living privately on your device.")
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(Self.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.8))
                                    .padding(.horizontal, 4)
                                HelpCard {
                                    VStack(spacing: 16) {
                                        ForEach(section.rows) { row in
                                            HelpRow(icon: row.icon, tint: row.tint,
                                                    title: row.title, text: row.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Content

    private static let sections: [HelpSection] = [
        HelpSection(title: "The Today screen", rows: [
            HelpItem(icon: "flame.fill", tint: .orange, title: "Your calorie ring",
                     text: "The big number is net calories for the day: your goal minus what you've eaten, plus any exercise adjustments. The ring fills as you log."),
            HelpItem(icon: "chart.pie.fill", tint: .blue, title: "Macros",
                     text: "Protein, carbs, and fat each get their own ring beneath the calories, tracked against your daily targets."),
            HelpItem(icon: "bolt.heart.fill", tint: .pink, title: "Exercise & adjustments",
                     text: "Tap the adjustments card to add or remove calories for a workout or a manual tweak. Adjustments raise your remaining budget for the day."),
        ]),
        HelpSection(title: "Logging food", rows: [
            HelpItem(icon: "plus.circle.fill", tint: .green, title: "The + button",
                     text: "Tap + in the dock to open the capture tools, then choose how you want to log."),
            HelpItem(icon: "mic.fill", tint: .green, title: "Voice",
                     text: "Say what you ate in plain language — “a bowl of oatmeal with blueberries.” It's transcribed and the food is recognised automatically."),
            HelpItem(icon: "camera.fill", tint: .green, title: "Photo",
                     text: "Snap your meal and the app estimates the items and their calories. Review and adjust before saving."),
            HelpItem(icon: "barcode.viewfinder", tint: .green, title: "Barcode",
                     text: "Scan a packaged product's barcode to pull its nutrition from the Open Food Facts database."),
            HelpItem(icon: "checkmark.seal.fill", tint: .teal, title: "Verify with label",
                     text: "After a barcode scan, tap “Verify with label” to scan the printed Nutrition Facts. You'll see a side-by-side comparison, and confirmed values are trusted for that product next time — shown as “Label verified.”"),
            HelpItem(icon: "keyboard", tint: .green, title: "Text",
                     text: "Prefer typing? Enter the food by hand and it's parsed just like voice."),
        ]),
        HelpSection(title: "Faster logging", rows: [
            HelpItem(icon: "repeat", tint: .indigo, title: "Your Usuals",
                     text: "Foods you log often appear as chips on Today — tap one to re-log it in a single step."),
            HelpItem(icon: "pencil", tint: .indigo, title: "Edit an entry",
                     text: "Tap any logged item to change its amount or details, or to delete it."),
            HelpItem(icon: "arrow.uturn.backward", tint: .indigo, title: "Undo",
                     text: "Logged something by mistake? Tap Undo on the toast that appears right after saving."),
        ]),
        HelpSection(title: "Apple Health", rows: [
            HelpItem(icon: "heart.fill", tint: .pink, title: "Nutrition sync",
                     text: "Optionally write your food entries to Apple Health so calories and macros sit alongside the rest of your health data."),
            HelpItem(icon: "figure.run", tint: .pink, title: "Workouts & active energy",
                     text: "With permission, the app notices your workouts and offers to add the calories you burned as an adjustment. Turn this on in Settings → Apple Health."),
            HelpItem(icon: "lock.shield", tint: .pink, title: "You're in control",
                     text: "Health access is opt-in and can be changed any time in Settings or the Health app. The app works fully without it."),
        ]),
        HelpSection(title: "History & trends", rows: [
            HelpItem(icon: "calendar", tint: .blue, title: "Browse past days",
                     text: "The History tab shows a calendar — tap any day to see exactly what you logged."),
            HelpItem(icon: "chart.xyaxis.line", tint: .blue, title: "Charts",
                     text: "Watch calories and macros trend over time so you can spot patterns."),
            HelpItem(icon: "scalemass.fill", tint: .blue, title: "Weight",
                     text: "Log your weight to track it on its own chart over weeks and months."),
        ]),
        HelpSection(title: "Privacy", rows: [
            HelpItem(icon: "iphone", tint: .gray, title: "On-device by design",
                     text: "Your food log lives in a private database on your iPhone. There's no account to create and nothing to sign in to."),
            HelpItem(icon: "wifi", tint: .gray, title: "What leaves your device",
                     text: "Only the words or photo you submit for recognition are sent — securely — to do the parsing, and barcode lookups query the public food database. Your diary itself is never uploaded."),
        ]),
        HelpSection(title: "Calorie Tracker Pro", rows: [
            HelpItem(icon: "gift.fill", tint: .purple, title: "Free to start",
                     text: "Your first \(Constants.freeFoodEntryLimit) food logs are free. After that, Pro unlocks unlimited logging and every input method."),
            HelpItem(icon: "infinity", tint: .purple, title: "What Pro includes",
                     text: "Unlimited food logging, voice / photo / barcode capture, Apple Health sync, and full history and trends."),
            HelpItem(icon: "arrow.clockwise", tint: .purple, title: "Restore purchases",
                     text: "Already subscribed on another device? Tap Restore Purchases on the upgrade screen — no account needed, it follows your Apple ID."),
        ]),
        HelpSection(title: "Accessibility", rows: [
            HelpItem(icon: "textformat.size", tint: .indigo, title: "Larger & Bold text",
                     text: "The app fully supports Dynamic Type and the system Bold Text setting (Settings → Accessibility → Display & Text Size)."),
            HelpItem(icon: "faceid", tint: .indigo, title: "Lock the app",
                     text: "Turn on the biometric lock in Settings to require Face ID or Touch ID before your diary opens."),
        ]),
    ]
}

private struct HelpSection: Identifiable {
    var id: String { title }
    let title: String
    let rows: [HelpItem]
}

private struct HelpItem: Identifiable {
    var id: String { title }
    let icon: String
    let tint: Color
    let title: String
    let text: String
}

/// A translucent, frosted panel. The Help guide is a temporary surface, so glass is
/// on-brand here (vs. the opaque matte cards used for persistent content) — it lets the
/// food photo show through softly while keeping the text readable on the material.
private struct HelpCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
}

/// One help topic on a card: a tinted glyph, a short title, and a one- or two-line
/// explanation.
private struct HelpRow: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
