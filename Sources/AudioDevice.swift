import CoreAudio

struct AudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
    var displayLabel: String

    /// The shared portion of the UID that identifies the physical hardware.
    /// For Apple Studio Displays: "AppleUSBAudioEngine:Apple Inc.:Studio Display:A1498802E:8,9"
    /// and "AppleUSBAudioEngine:Apple Inc.:Studio Display Microphone:A1498802E:6,7"
    /// share the serial "A1498802E". We extract up to (but not including) the last colon-segment.
    var hardwareGroupKey: String {
        // Try to find a serial-like segment: split by ":" and look for the hex serial
        let parts = uid.split(separator: ":")
        // For Apple USB Audio, the format is vendor:product:serial:channels
        // The serial is typically the 4th-to-last or a hex string
        // Simpler approach: drop the last segment (channel config like "8,9" or "6,7")
        // and drop the product name segment to get a stable grouping key
        if parts.count >= 4 {
            // Use vendor + serial: parts[0] (engine) + parts[1] (vendor) + parts[3] (serial)
            return "\(parts[0]):\(parts[1]):\(parts[3])"
        }
        return uid
    }
}

/// A group of devices that belong to the same physical hardware (e.g., one Studio Display)
struct DeviceGroup: Identifiable {
    let id: String // the hardware group key
    let physicalName: String // e.g., "Studio Display"
    let serial: String // e.g., "A1498802E"
    let output: AudioDevice?
    let input: AudioDevice?
    var customName: String? // user-assigned name

    var displayLabel: String {
        customName ?? physicalName
    }
}
