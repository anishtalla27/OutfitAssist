import AVFoundation

enum SpeechStyle {
    static func preparePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }

    static func utterance(_ text: String, rate: Float = 0.46) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.prefersAssistiveTechnologySettings = true
        utterance.voice = preferredVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = 1.03
        utterance.volume = 1.0
        return utterance
    }

    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }

        let preferredNames = ["ava", "samantha", "zoe", "allison", "susan"]
        let preferredQualities: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]

        for quality in preferredQualities {
            for name in preferredNames {
                if let voice = voices.first(where: {
                    $0.quality == quality && $0.name.localizedCaseInsensitiveContains(name)
                }) {
                    return voice
                }
            }
        }

        return AVSpeechSynthesisVoice(identifier: AVSpeechSynthesisVoiceIdentifierAlex)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
