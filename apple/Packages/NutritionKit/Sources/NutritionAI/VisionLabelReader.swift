// LabelReading via on-device Vision OCR (iOS 26 `RecognizeTextRequest`, accurate
// level) → deterministic `NutritionLabelParser`. If the regex parse can't anchor
// on a calorie value and Foundation Models is available, the raw OCR text is
// handed to the FM food parser as a fallback interpretation. Fully on-device.

import Foundation
import Vision
import ImageIO
import CoreGraphics
import NutritionCore

public enum LabelReadingError: Error, Sendable, Equatable {
    case invalidImage
    case noNutritionInfo
}

public struct VisionLabelReader: LabelReading {
    /// Optional model-backed fallback when the regex parse fails.
    private let refiner: FoundationModelsFoodParser?

    public init(refiner: FoundationModelsFoodParser? = FoundationModelsFoodParser()) {
        self.refiner = refiner
    }

    public func readNutritionLabel(imageData: Data, units: UnitSystem) async throws -> ParsedFood {
        let lines = try await Self.recognizeText(imageData)

        if let parsed = NutritionLabelParser.parse(lines: lines) {
            return parsed
        }
        // Fallback: let the on-device model interpret the raw OCR text.
        if let refiner, FoundationModelsFoodParser.isAvailable, !lines.isEmpty {
            return try await refiner.parse(text: lines.joined(separator: "\n"), units: units)
        }
        throw LabelReadingError.noNutritionInfo
    }

    // MARK: - Vision OCR

    static func recognizeText(_ data: Data) async throws -> [String] {
        guard let cgImage = cgImage(from: data) else { throw LabelReadingError.invalidImage }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        let observations = try await request.perform(on: cgImage)
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
