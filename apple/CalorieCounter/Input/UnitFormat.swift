//
//  UnitFormat.swift
//  Shared compact formatting for amount fields after a unit conversion.
//

import Foundation

enum UnitFormat {
    /// Whole numbers print without a decimal; otherwise up to 2 decimals.
    static func amount(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%g", rounded)
    }
}
