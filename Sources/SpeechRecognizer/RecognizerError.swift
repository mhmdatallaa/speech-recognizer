//
//  RecognizerError.swift
//  SpeechRecognizer
//
//  Created by Mohamed Atallah on 05/06/2025.
//

/// ## Error Types
public enum RecognizerError: Error {
    case nilRecognizer
    case notAuthorizedToRecognize
    case notPermittedToRecord
    case recognizerIsUnavailable
    
    public var message: String {
        switch self {
        case .nilRecognizer: "can't initialize speech recognizer"
        case .notAuthorizedToRecognize: "Not authorized to recognize speech"
        case .notPermittedToRecord: "Not permitted to record audio"
        case .recognizerIsUnavailable: "Recognizer is unavailable"
        }
    }
}
