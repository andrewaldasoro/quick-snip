import CoreGraphics

/// Tries `primary`, and `fallback` when it throws. Vision's accurate recognizer fails with
/// `CRImageReaderError.unknownError` where its model can't run (seen on GitHub's macOS VMs);
/// the fast one may still work there.
struct FallbackTextRecognizer: TextRecognizing {
    let primary: any TextRecognizing
    let fallback: any TextRecognizing

    static let vision = FallbackTextRecognizer(
        primary: VisionTextRecognizer(level: .accurate),
        fallback: VisionTextRecognizer(level: .fast)
    )

    func recognizeText(in image: CGImage) async throws -> String {
        do {
            return try await primary.recognizeText(in: image)
        } catch {
            return try await fallback.recognizeText(in: image)
        }
    }
}
