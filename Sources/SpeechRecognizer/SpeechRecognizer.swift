import AVFoundation
import Speech
import Observation


// ## SpeechRecognizer
/// An actor-based speech recognition system that handles audio processing and transcript updates
/// while maintaining thread safety through Swift concurrency.
///
/// ### Key Features:
/// - MainActor-bound transcript updates for UI safety
/// - Async/await permission handling
/// - Audio session lifecycle management
/// - Error handling with localized messages
///
/// ### Requirements:
/// Add these to your Info.plist:
/// ```
/// <key>NSMicrophoneUsageDescription</key>
/// <string>Need microphone access for speech recognition</string>
/// <key>NSSpeechRecognitionUsageDescription</key>
/// <string>Need speech recognition access</string>
/// ```
public actor SpeechRecognizer: Observable {
    
    /// Current transcription text (MainThread-safe)
    @MainActor public private(set) var transcript: String = ""
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    // MARK: - Initialization
    
    public init() {
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            transcribe(RecognizerError.nilRecognizer)
            return
        }
        
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                transcribe(error)
            }
        }
    }
    
    /// Starts the speech transcription process on the main actor.
    @MainActor public func startTranscribing() {
        Task { await transcribe() }
    }
    
    /// Resets the current transcript on the main actor.
    @MainActor public func resetTranscript() {
        Task { await reset() }
    }
    
    /// stop the current transcript on the main actor.
    @MainActor public func stopTranscribing() {
        Task { await reset() }
    }
    
    
    /// Starts the speech recognition process by configuring audio input and handling recognition results.
    ///
    /// This function performs the following steps:
    /// 1. Checks if the speech recognizer is available. If not, it reports an error.
    /// 2. Prepares the audio engine and recognition request by calling `prepareEngine()`.
    /// 3. Stores references to the audio engine and recognition request for lifecycle management.
    /// 4. Creates a recognition task with the speech recognizer, providing a result handler closure
    ///    that processes recognition results and errors asynchronously.
    /// 5. If any error occurs during setup, it resets the state and reports the error.
    ///
    /// - Important:
    ///   - The function uses a weak reference to `self` in the result handler to avoid retain cycles.
    ///   - The recognition task and audio engine need to be properly stopped and cleaned up elsewhere.
    ///
    /// - Throws: No direct throws, but errors from `prepareEngine()` are caught and handled internally.
    ///
    /// - Note: The function assumes `recognizer` is an instance of `SFSpeechRecognizer?`,
    ///   and that `transcribe(_:)`, `reset()`, and `recognitionHandler(audioEngin:result:error:)`
    ///   are implemented in the containing type.
    private func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            self.transcribe(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let (audioEngine, request) = try Self.prepareEngine()
            self.audioEngine = audioEngine
            self.request = request
            self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                self?.recognitionHandler(audioEngin: audioEngine, result: result, error: error)
            })
        } catch {
            self.reset()
            self.transcribe(error)
        }
    }
    
    ///  Reset the speech recognizer.
    private func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    ///Creates and configures audio components for speech recognition
    /// - Returns: Tuple containing:
    ///   - `AVAudioEngine`: Configured audio engine instance
    ///   - `SFSpeechAudioBufferRecognitionRequest`: Audio buffer request
    /// - Throws: `AVAudioSession` or audio engine configuration errors
    ///
    /// ## Configuration Details
    /// 1. **Audio Session Setup**:
    ///    - Category: `.playAndRecord` (simultaneous input/output)
    ///    - Mode: `.measurement` (optimized for voice processing)
    ///    - Options: `.duckOthers` (lower other app volumes)
    /// 2. **Audio Hardware**:
    ///    - Activates audio session with `.notifyOthersOnDeactivation`
    ///    - Uses input node's native format (44.1kHz, stereo typically)
    /// 3. **Buffer Handling**:
    ///    - 1024 frame buffer size (balanced latency/performance)
    ///    - Automatic buffer appending to recognition request
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    /// Handles speech recognition results and manages audio engine lifecycle
    /// - Parameters:
    ///   - audioEngine: The AVAudioEngine processing audio input
    ///   - result: Optional speech recognition result containing transcriptions
    ///   - error: Optional error indicating recognition failure
    ///
    /// ## Usage
    /// This closure:
    /// 1. Checks for final results or errors to stop audio processing
    /// 2. Extracts best transcription from valid results∫
    /// 3. Manages audio engine resources
    ///
    /// ### Key Logic Flow:
    /// - Stops audio processing when either:
    ///   - Final transcription received (`result?.isFinal == true`)
    ///   - Error occurs (`error != nil`)
    /// - Processes valid results through `transcribe(_:)` method
    ///
    /// ### Important Notes:
    /// - Private/nonisolated access modifier indicates:
    ///   - Not exposed outside containing type
    ///   - Safe for concurrent access (no actor isolation)
    /// - Requires `transcribe(_:)` implementation to handle string output
    /// - Main operations:
    ///   - `audioEngine.stop()` - Halts audio processing
    ///   - `removeTap(onBus: 0)` - Removes audio input tap
    ///   - `bestTranscription.formattedString` - Gets most accurate transcription

    nonisolated private func recognitionHandler(audioEngin: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let recievedFinalResult = result?.isFinal ?? false
        let recieveError = error != nil
        
        if recievedFinalResult || recieveError {
            audioEngin.stop()
            audioEngin.inputNode.removeTap(onBus: 0)
        }
        if let result {
            transcribe(result.bestTranscription.formattedString)
        }
    }
    
    /// Updates the transcript string on the main actor asynchronously
    nonisolated private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    
    /// Handles transcription errors by converting the error into a user-friendly message
    nonisolated private func transcribe(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}

// MARK: - Permission Extensions

extension SFSpeechRecognizer {
    /// Asynchronously requests the user's authorization to perform speech recognition
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    /// Asynchronously requests the user's permission to record audio and returns the result.
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
