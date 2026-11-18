import Foundation
import AVFoundation

public final class AudioSpeaker: ObservableObject {
    public static let shared = AudioSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {}
    
    /// Pronounces text in German using native iOS de-DE voice
    public func speak(text: String, rate: Float = 0.48) {
        // Stop any currently playing utterance
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        
        // Configure audio session to play nicely with device silent switch if needed
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.speak(utterance)
    }
}
