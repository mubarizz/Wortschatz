import Foundation
import AVFoundation
import Network

public final class AudioSpeaker: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = AudioSpeaker()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var currentTask: URLSessionDataTask?
    private var audioCache: [String: Data] = [:]
    private let cacheLock = NSLock()
    
    // Real-time network monitor for instant offline fallback on physical devices
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mubarizz.Wortschatz.NetworkMonitor")
    private var isNetworkAvailable: Bool = true
    
    private override init() {
        super.init()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = (path.status == .satisfied)
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    /// Pronounces text in German using natural de-DE TTS audio with instant offline AVSpeechSynthesizer fallback
    public func speak(text: String, rate: Float = 0.48) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }
        
        stopCurrentPlayback()
        configureAudioSession()
        
        // 1. Check in-memory audio cache first for instant playback (even offline if previously played)
        cacheLock.lock()
        let cachedData = audioCache[cleanedText]
        cacheLock.unlock()
        
        if let data = cachedData {
            if playAudioData(data, rate: rate) {
                return
            }
        }
        
        // 2. If device has no internet connection, immediately use built-in iOS offline German voice (0ms wait)
        guard isNetworkAvailable else {
            speakWithAVSpeech(text: cleanedText, rate: rate)
            return
        }
        
        // 3. Fetch natural German TTS audio
        guard let encoded = cleanedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/translate_tts?ie=UTF-8&q=\(encoded)&tl=de&client=tw-ob") else {
            speakWithAVSpeech(text: cleanedText, rate: rate)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 3.0
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if let data = data, error == nil, httpStatus == 200, !data.isEmpty {
                self.cacheLock.lock()
                self.audioCache[cleanedText] = data
                self.cacheLock.unlock()
                
                DispatchQueue.main.async {
                    if !self.playAudioData(data, rate: rate) {
                        self.speakWithAVSpeech(text: cleanedText, rate: rate)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.speakWithAVSpeech(text: cleanedText, rate: rate)
                }
            }
        }
        currentTask = task
        task.resume()
    }
    
    /// Stops any active speech or audio playback immediately
    public func stop() {
        stopCurrentPlayback()
    }
    
    private func stopCurrentPlayback() {
        currentTask?.cancel()
        currentTask = nil
        
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            NSLog("[AudioSpeaker] AVAudioSession error: %@", "\(error)")
        }
    }
    
    @discardableResult
    private func playAudioData(_ data: Data, rate: Float = 0.48) -> Bool {
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 1.0
            player.enableRate = true
            // Map AVSpeechUtterance rate (~0.48 normal, ~0.32 slow) to AVAudioPlayer playback rate (1.0 normal, 0.72 slow)
            if rate < 0.40 {
                player.rate = 0.72
            } else {
                player.rate = 1.0
            }
            player.prepareToPlay()
            let started = player.play()
            if started {
                self.audioPlayer = player
            }
            return started
        } catch {
            NSLog("[AudioSpeaker] AVAudioPlayer error: %@", "\(error)")
            return false
        }
    }
    
    private func speakWithAVSpeech(text: String, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: { $0.language == "de-DE" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
}
