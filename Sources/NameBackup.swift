import Foundation

/// A file with your custom device names, for moving them to another Mac.
/// Names are keyed by hardware ID (a display's serial, a Bluetooth address, or a device name),
/// so they match the same devices on any Mac.
struct NameBackup: Codable {
    var app = "macOS Audio Renamer"
    var formatVersion = 1
    var exportedAt: Date
    var names: [String: String]
}

enum NameTransfer {
    enum Failure: LocalizedError {
        case noNames
        var errorDescription: String? { "This file doesn't contain any device names." }
    }

    static func exportData(names: [String: String], date: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(NameBackup(exportedAt: date, names: cleaned(names)))
    }

    /// Reads a backup file, or a plain `{"device id": "name"}` object.
    static func names(from data: Data) throws -> [String: String] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let names = (try? decoder.decode(NameBackup.self, from: data).names)
            ?? (try? decoder.decode([String: String].self, from: data))
            ?? [:]
        let result = cleaned(names)
        if result.isEmpty { throw Failure.noNames }
        return result
    }

    /// Adds imported names to the current ones. Where both have a name for a device, the
    /// imported one wins: importing is how you bring your names with you.
    static func merge(_ imported: [String: String], into current: [String: String])
        -> (names: [String: String], added: Int, changed: Int) {
        var names = current
        var added = 0, changed = 0
        for (key, name) in imported {
            switch names[key] {
            case nil: added += 1
            case name?: continue
            default: changed += 1
            }
            names[key] = name
        }
        return (names, added, changed)
    }

    private static func cleaned(_ names: [String: String]) -> [String: String] {
        names.filter { !$0.key.isEmpty && !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
