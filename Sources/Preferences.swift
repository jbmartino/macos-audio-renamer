import Foundation

enum Preferences {
    private static let inputKey = "preferredInputUID"
    private static let outputKey = "preferredOutputUID"
    private static let customNamesKey = "customDeviceNames"
    private static let switchInputWithOutputKey = "switchInputWithOutput"
    private static let hasOfferedLoginItemKey = "hasOfferedLoginItem"

    static var preferredInputUID: String? {
        get { UserDefaults.standard.string(forKey: inputKey) }
        set { UserDefaults.standard.set(newValue, forKey: inputKey) }
    }

    static var preferredOutputUID: String? {
        get { UserDefaults.standard.string(forKey: outputKey) }
        set { UserDefaults.standard.set(newValue, forKey: outputKey) }
    }

    /// When choosing a speaker from the menu, also switch to the same device's microphone.
    static var switchInputWithOutput: Bool {
        get { UserDefaults.standard.object(forKey: switchInputWithOutputKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: switchInputWithOutputKey) }
    }

    /// Whether the one-time "Open at login?" question has been asked.
    static var hasOfferedLoginItem: Bool {
        get { UserDefaults.standard.bool(forKey: hasOfferedLoginItemKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasOfferedLoginItemKey) }
    }

    /// Custom names keyed by either a hardware group key (one name for the whole physical
    /// device) or a device UID (a per-speaker / per-mic override).
    static var customNames: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: customNamesKey) }
    }

    static func customName(for key: String) -> String? {
        let name = customNames[key]?.trimmingCharacters(in: .whitespaces)
        return (name?.isEmpty ?? true) ? nil : name
    }

    static func setCustomName(_ name: String?, for key: String) {
        var names = customNames
        let trimmed = name?.trimmingCharacters(in: .whitespaces)
        names[key] = (trimmed?.isEmpty ?? true) ? nil : name
        customNames = names
    }

    static func resetAllNames() {
        customNames = [:]
    }
}
