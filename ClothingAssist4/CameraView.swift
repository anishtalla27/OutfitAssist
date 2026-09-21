import SwiftUI
@preconcurrency import AVFoundation
import Combine

// MARK: - Camera model

final class CameraModel: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    // serial queue keeps all session work off the main thread
    private let sessionQueue = DispatchQueue(label: "camera.session")
    var onCapture: ((UIImage) -> Void)?

    func setup() {
        // check permission first, only touch the session after we have it
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            sessionQueue.async { self.configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                self.sessionQueue.async { self.configureAndStart() }
            }
        default:
            break
        }
    }

    private func configureAndStart() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        // startRunning blocks until ready, must stay on sessionQueue
        session.startRunning()
    }

    func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func stop() {
        sessionQueue.async { [s = self.session] in
            if s.isRunning { s.stopRunning() }
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in self.onCapture?(image) }
    }
}

// MARK: - Preview layer (UIKit bridge)

private final class PreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

private struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

// MARK: - View

struct CameraView: View {
    let router: AppRouter
    let transcript: String

    @StateObject private var camera = CameraModel()
    @State private var isLoading = false
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isLoading else { return }
                    capture()
                }

            VStack(spacing: 0) {
                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2.0)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 110)
                } else {
                    Button(action: capture) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 34)
                                .fill(.white.opacity(0.28))
                            RoundedRectangle(cornerRadius: 34)
                                .strokeBorder(.white.opacity(0.95), lineWidth: 6)

                            VStack(spacing: 14) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 58, weight: .bold))

                                Text("Take Picture")
                                    .font(.system(size: 32, weight: .bold))

                                Text("Tap anywhere on screen")
                                    .font(.system(size: 21, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 285)
                        .padding(.horizontal, 22)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Take photo")
                    .accessibilityHint("Tap anywhere on the screen to take a photo of the clothing pieces.")
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            camera.setup()
            speak("Camera ready. Point at the clothing pieces and tap anywhere on the screen to take a picture to be scanned.")
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
            camera.stop()
        }
    }

    private func capture() {
        isLoading = true
        speak("Photo captured. Analyzing now.")
        camera.onCapture = { image in
            // compress harder so the payload doesn't drop the connection
            guard let jpeg = image.jpegData(compressionQuality: 0.4) else {
                isLoading = false
                speak("I could not use that photo. Please try again.")
                return
            }
            let base64 = jpeg.base64EncodedString()

            ClaudeService.analyze(transcript: transcript, image: base64) { response in
                router.path.append(Route.result(text: response))
                isLoading = false
            }
        }
        camera.capturePhoto()
    }

    private func speak(_ text: String) {
        SpeechStyle.preparePlayback()
        let utterance = SpeechStyle.utterance(text, rate: 0.48)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}
