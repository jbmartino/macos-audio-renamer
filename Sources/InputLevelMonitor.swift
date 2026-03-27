import AVFoundation
import CoreAudio

class InputLevelMonitor {
    private var engine: AVAudioEngine?
    var onLevel: ((Float) -> Void)?

    func start(deviceUID: String) {
        stop()

        let engine = AVAudioEngine()
        self.engine = engine

        // Set the input device on the underlying AudioUnit
        let inputNode = engine.inputNode
        let audioUnit = inputNode.audioUnit!

        // Set input device by AudioObjectID
        setInputByID(audioUnit: audioUnit, deviceUID: deviceUID)

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            guard let data = channelData, frameLength > 0 else { return }

            // Compute RMS
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = data[i]
                sum += sample * sample
            }
            let rms = sqrtf(sum / Float(frameLength))
            // Scale to 0-1 range (typical speech RMS is ~0.01-0.1)
            let level = min(rms * 10, 1.0)

            DispatchQueue.main.async {
                self?.onLevel?(level)
            }
        }

        do {
            try engine.start()
        } catch {
            self.engine = nil
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    private func setInputByID(audioUnit: AudioUnit, deviceUID: String) {
        // Find the AudioObjectID for this UID and set it directly
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else { return }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs) == noErr else { return }

        for id in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &size, &name) == noErr,
               let value = name?.takeRetainedValue() as String?,
               value == deviceUID {
                var deviceID = id
                AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioObjectID>.size)
                )
                return
            }
        }
    }
}
