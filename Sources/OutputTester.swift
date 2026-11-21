import AVFoundation
import CoreAudio

/// Plays a short chime directly on one output device without changing the system default.
final class OutputTester {
    private var engine: AVAudioEngine?
    private(set) var playingUID: String?
    var onFinish: (() -> Void)?

    func toggle(uid: String, deviceID: AudioObjectID) {
        if playingUID == uid {
            stop()
            return
        }
        stop()
        play(uid: uid, deviceID: deviceID)
    }

    func stop() {
        engine?.stop()
        engine = nil
        playingUID = nil
    }

    private func play(uid: String, deviceID: AudioObjectID) {
        let engine = AVAudioEngine()
        guard let outputUnit = engine.outputNode.audioUnit else { return }

        // Route output to the target device directly (no system default switching)
        var devID = deviceID
        AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &devID,
            UInt32(MemoryLayout<AudioObjectID>.size)
        )

        // Stereo at 44.1kHz — AVAudioEngine handles sample rate conversion
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Gentle two-tone chime
        let duration = 0.8
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let freq1: Double = 523.25  // C5
        let freq2: Double = 659.25  // E5
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(min(t / 0.02, 1.0) * exp(-t * 3.0))
            let sample = Float(sin(2.0 * .pi * freq1 * t) + 0.6 * sin(2.0 * .pi * freq2 * t))
            let value = sample * envelope * 0.3
            buffer.floatChannelData![0][i] = value
            buffer.floatChannelData![1][i] = value
        }

        do {
            try engine.start()
            self.engine = engine
            playingUID = uid
            player.play()
            player.scheduleBuffer(buffer) { [weak self, weak engine] in
                DispatchQueue.main.async {
                    guard let self, self.engine === engine else { return }
                    self.stop()
                    self.onFinish?()
                }
            }
        } catch {
            stop()
        }
    }
}
