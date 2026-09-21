import SwiftUI
import AVFoundation

struct ResultView: View {
    let router: AppRouter
    let text: String

    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(text)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer()

                Button {
                    synthesizer.stopSpeaking(at: .immediate)
                    router.popToRoot()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 44, weight: .bold))

                        Text("Try Again")
                            .font(.system(size: 36, weight: .bold))
                    }
                    .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .background(.white, in: RoundedRectangle(cornerRadius: 28))
                        .padding(.horizontal, 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Try again")
                .accessibilityHint("Returns to the first screen so you can ask another question.")
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { speak() }
        .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func speak() {
        SpeechStyle.preparePlayback()
        let spokenText = "\(text) Tap anywhere near the bottom to try again."
        let utterance = SpeechStyle.utterance(spokenText, rate: 0.45)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}
