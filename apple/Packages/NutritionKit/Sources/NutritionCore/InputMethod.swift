// The four ways a food entry can be captured. Ported from the web union
// `Entry['method']` ('barcode' | 'voice' | 'text' | 'photo') in
// `src/types/index.ts` and the `INPUT_METHODS` metadata in
// `src/lib/constants.ts`. Stored on the wire as the raw string, so the cases'
// raw values MUST match the web strings exactly.

import Foundation

public enum InputMethod: String, Codable, Sendable, CaseIterable, Identifiable {
    case barcode
    case voice
    case text
    case photo

    /// Identity for SwiftUI `.sheet(item:)` etc. (the raw wire string is stable).
    public var id: String { rawValue }

    /// Short title (web `INPUT_METHODS[*].label`).
    public var label: String {
        switch self {
        case .barcode: return "Barcode"
        case .voice: return "Voice"
        case .text: return "Text"
        case .photo: return "Photo"
        }
    }

    /// One-line description (web `INPUT_METHODS[*].description`).
    public var detail: String {
        switch self {
        case .barcode: return "Scan product barcode"
        case .voice: return "Speak your food"
        case .text: return "Type food name"
        case .photo: return "Take a photo of food"
        }
    }

    /// SF Symbol used by the input buttons (iOS-only presentation hint).
    public var systemImage: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .voice: return "mic.fill"
        case .text: return "keyboard"
        case .photo: return "camera.fill"
        }
    }
}
