import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Navigation

enum Route: Hashable {
    case camera(transcript: String)
    case result(text: String)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func popToRoot() {
        path = NavigationPath()
    }
}

// MARK: - Speech

@MainActor
final class SpeechModel: ObservableObject {
    @Published var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    // track whether we actually installed a tap so stop() doesn't crash
    private var tapInstalled = false
    private var wantsCapture = false
    private var isCapturing = false

    func start() {
        wantsCapture = true
        guard !isCapturing else { return }

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                Task { @MainActor in
                    guard self.wantsCapture else { return }
                    self.beginCapture()
                }
            }
        }
    }

    private func beginCapture() {
        guard wantsCapture, !isCapturing else { return }

        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            self?.recognitionRequest?.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isCapturing = true
        } catch {
            cleanupCapture()
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor in
                if let result { self?.transcript = result.bestTranscription.formattedString }
            }
        }
    }

    func stop() -> String {
        wantsCapture = false
        cleanupCapture()
        return transcript
    }

    private func cleanupCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isCapturing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Home

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var speech = SpeechModel()

    @State private var status = "Hold to speak"
    @State private var isPressed = false
    @State private var synthesizer = AVSpeechSynthesizer()

    private let directionsText = """
    Welcome to OutfitAssist. Hold anywhere near the bottom and say what you need to wear, \
    like make me a casual outfit or what matches best. Then release. Tap anywhere near \
    the top to hear directions again.
    """

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        directionsArea
                            .frame(width: proxy.size.width, height: proxy.size.height * 0.4)
                            .background(Color.blue.opacity(0.85))

                        middleBuffer
                            .frame(width: proxy.size.width, height: proxy.size.height * 0.2)
                            .background(Color.white)

                        microphoneArea
                            .frame(width: proxy.size.width, height: proxy.size.height * 0.4)
                            .background(isPressed ? Color.red.opacity(0.95) : Color.red.opacity(0.82))
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .camera(let transcript):
                    CameraView(router: router, transcript: transcript)
                case .result(let text):
                    ResultView(router: router, text: text)
                }
            }
            .onAppear { speakDirections() }
            .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
        }
    }

    private func speakDirections() {
        SpeechStyle.preparePlayback()
        let utterance = SpeechStyle.utterance(directionsText, rate: 0.36)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private var directionsArea: some View {
        Button(action: speakDirections) {
            VStack(spacing: 16) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 52, weight: .bold))

                Text("Directions")
                    .font(.system(size: 38, weight: .bold))

                Text("Tap anywhere here")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read directions again")
        .accessibilityHint("Tap anywhere in the top area to hear the OutfitAssist instructions.")
    }

    private var middleBuffer: some View {
        Color.clear
        .accessibilityHidden(true)
    }

    private var microphoneArea: some View {
        ZStack {
            VStack(spacing: 18) {
                Image(systemName: isPressed ? "mic.fill" : "mic")
                    .font(.system(size: 70, weight: .bold))

                Text(isPressed ? "Listening" : "Hold to Speak")
                    .font(.system(size: 38, weight: .bold))

                Text("Hold anywhere here")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityElement()
        .accessibilityLabel("Hold to speak")
        .accessibilityHint("Hold anywhere in the bottom area while saying what outfit help you want, then release.")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    synthesizer.stopSpeaking(at: .immediate)
                    status = "Listening..."
                    speech.start()
                }
                .onEnded { _ in
                    guard isPressed else { return }
                    isPressed = false
                    let captured = speech.stop()
                    status = "Hold to speak"
                    router.path.append(Route.camera(transcript: captured))
                }
        )
    }
}

#Preview {
    ContentView()
}
