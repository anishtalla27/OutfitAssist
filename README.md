# OutfitAssist

A voice-first iOS app that helps blind and low-vision users pick out what to wear. Say what you need, snap a photo of your clothing options, and OutfitAssist tells you out loud which pieces are there, what colors they are, and what goes together.

## How it works

1. **Hold to speak.** Press and hold the bottom of the screen and say what you want, like *"make me a casual outfit"* or *"which shirt matches these pants?"*. Release when you're done.
2. **Take a picture.** The camera opens. Point it at your clothes (laid out on a bed, hanging in a closet, etc.) and tap anywhere on the screen.
3. **Listen.** The photo and your spoken request are sent to Claude, and the answer is read aloud: the visible items and colors first, then the outfit advice.
4. **Try again.** One big button takes you back to the start.

## Designed for non-visual use

- **No small targets.** Every screen is made of huge tap zones: the top of the home screen repeats the directions, the bottom is the microphone, and the entire camera screen is the shutter button.
- **Everything is spoken.** Directions on launch, "camera ready", "photo captured, analyzing now", the result, and any errors are all read aloud with `AVSpeechSynthesizer`.
- **Natural voice.** Picks the best installed en-US voice (premium → enhanced → default) and respects the user's assistive speech settings.
- **VoiceOver friendly.** Controls carry accessibility labels and hints; decorative areas are hidden from VoiceOver.
- **Honest answers.** The model is instructed to be specific about colors and item types, to say when it's unsure rather than guess, and never to invent clothing that isn't in the photo.

## Tech stack

| Piece | Used for |
| --- | --- |
| SwiftUI + `NavigationStack` | UI and routing (home → camera → result) |
| Speech (`SFSpeechRecognizer`) + `AVAudioEngine` | Live transcription of the spoken request |
| AVFoundation (`AVCaptureSession`) | Rear camera preview and photo capture |
| `AVSpeechSynthesizer` | All spoken feedback |
| [Anthropic Messages API](https://docs.anthropic.com/en/api/messages) | Vision + reasoning over the photo and request |

No third-party dependencies.

## Project layout

```
ClothingAssist4/
├── OutfitAssistApp.swift   # App entry point
├── ContentView.swift       # Home screen, router, speech recognition
├── CameraView.swift        # Camera preview, capture, handoff to Claude
├── ClaudeService.swift     # API request, system prompt, retry logic
├── ResultView.swift        # Shows and speaks the answer
├── SpeechStyle.swift       # Voice selection and utterance settings
├── Config.swift            # Loads the API key from secrets.plist
└── secrets.example.plist   # Template for your API key
```

## Getting started

**Requirements:** Xcode 26+, an iPhone running iOS 26.2+ (the camera and microphone need a real device), and an [Anthropic API key](https://console.anthropic.com/).

1. Clone the repo and open the project:
   ```bash
   git clone https://github.com/anishtalla27/OutfitAssist.git
   open OutfitAssist/ClothingAssist4.xcodeproj
   ```
2. Add your API key:
   ```bash
   cd OutfitAssist/ClothingAssist4
   cp secrets.example.plist secrets.plist
   ```
   Then replace `YOUR_ANTHROPIC_API_KEY` in `secrets.plist` with your key. This file is git-ignored; make sure it's included in the app target.
3. Select your development team under *Signing & Capabilities*, choose your iPhone, and run.
4. Allow camera, microphone, and speech recognition access when prompted.

## Privacy and security notes

- A photo and the transcript of your request are sent to Anthropic's API for each analysis. Nothing is stored by the app.
- The API key is bundled into the app at build time, which is fine for personal use and demos but **not** safe for App Store distribution. For a public release, route requests through your own backend instead.

## Author

Built by [Anish Talla](https://github.com/anishtalla27).
