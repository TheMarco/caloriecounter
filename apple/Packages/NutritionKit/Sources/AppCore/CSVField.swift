// RFC-4180-style CSV field helpers shared by the per-entry export/import. Food
// names can contain commas, so fields are quoted/escaped on the way out and parsed
// with quote-awareness on the way in.

import Foundation

enum CSV {
    /// Quote a field if it contains a comma, quote, or newline (doubling inner quotes).
    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Split one CSV line into fields, honoring quoted fields and "" escapes.
    static func split(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        current.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",":  fields.append(current); current = ""
                default:   current.append(c)
                }
            }
            i += 1
        }
        fields.append(current)
        return fields
    }
}
