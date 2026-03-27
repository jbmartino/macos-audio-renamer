import Foundation

enum Preferences {
    private static let inputKey = "preferredInputUID"
    private static let outputKey = "preferredOutputUID"
    private static let customNamesKey = "customDeviceNames"

    static var preferredInputUID: String? {
        get { UserDefaults.standard.string(forKey: inputKey) }
        set { UserDefaults.standard.set(newValue, forKey: inputKey) }
    }

    static var preferredOutputUID: String? {
        get { UserDefaults.standard.string(forKey: outputKey) }
        set { UserDefaults.standard.set(newValue, forKey: outputKey) }
    }

    /// Custom names keyed by either device UID or hardware group key
    static var customNames: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: customNamesKey) }
    }

    static func customName(for key: String) -> String? {
        let name = customNames[key]
        return (name?.isEmpty == true) ? nil : name
    }

    static func setCustomName(_ name: String?, for key: String) {
        var names = customNames
        names[key] = name
        customNames = names
    }
}
