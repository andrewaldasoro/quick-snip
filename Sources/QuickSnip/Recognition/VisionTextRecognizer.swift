import CoreGraphics
import Vision

/// Reads the text in an image.
protocol TextRecognizing: Sendable {
    func recognizeText(in image: CGImage) async throws -> String
}

/// Apple's Vision text recognition. Runs on the device: nothing leaves the Mac.
struct VisionTextRecognizer: TextRecognizing {
    var level: RecognizeTextRequest.RecognitionLevel = .accurate

    func recognizeText(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = level
        request.usesLanguageCorrection = level == .accurate
        request.automaticallyDetectsLanguage = level == .accurate
        let observations = try await request.perform(on: image)
        let fragments = observations.compactMap { observation in
            observation.topCandidates(1).first.map { TextFragment(text: $0.string, bounds: observation.boundingBox.cgRect) }
        }
        return TextFragment.readingOrder(fragments)
    }
}
