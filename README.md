# SpeechRecognizer

A Swift Package that provides a simple, actor-based speech-to-text solution using Apple's `SFSpeechRecognizer` and `AVAudioEngine`. Designed for easy integration into your iOS apps with Swift concurrency support.

## Features

- Real-time speech transcription with continuous updates.
- Actor-based concurrency for thread-safe state management.
- Async/await permission handling for microphone and speech recognition.
- Clear error reporting with user-friendly messages.
- Minimal setup with Swift Package Manager.

## Usage


https://github.com/user-attachments/assets/f6b3c4db-9540-4293-9580-3771bf8df04c


1.  **Import the `SpeechRecognizer` class:**

    ```
    import SpeechRecognizer
    ```

2.  **Instantiate the `SpeechRecognizer`:**

    ```
    import SwiftUI
    import SpeechRecognizer

    struct ContentView: View {
        @State private var speechRecognizer = SpeechRecognizer()
        @State private var isTranscribing = false

        var body: some View {
            VStack {
                Text(speechRecognizer.transcript)
                    .padding()

                Button(action: {
                    if isTranscribing {
                        speechRecognizer.stopTranscribing()
                    } else {
                        speechRecognizer.startTranscribing()
                    }
                    isTranscribing.toggle()
                }) {
                    Text(isTranscribing ? "Stop Transcribing" : "Start Transcribing")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    ```
3.  **Add Microphone and Speech Recognition Usage Descriptions to your `Info.plist`:**

    *   `NSMicrophoneUsageDescription`:  A description of why your app needs access to the microphone.
    *   `NSSpeechRecognitionUsageDescription`: A description of why your app needs to perform speech recognition.
