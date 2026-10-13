import CoreGraphics
import Testing

@testable import QuickSnip

struct FallbackTextRecognizerTests {
    private struct Stub: TextRecognizing {
        let result: Result<String, TestError>
        func recognizeText(in image: CGImage) async throws -> String { try result.get() }
    }

    private let image = TestImages.solidImage(width: 4, height: 4, color: RGBA(r: 255, g: 255, b: 255, a: 255))

    @Test func usesThePrimaryWhenItWorks() async throws {
        let recognizer = FallbackTextRecognizer(primary: Stub(result: .success("accurate")), fallback: Stub(result: .success("fast")))
        #expect(try await recognizer.recognizeText(in: image) == "accurate")
    }

    /// Regression: on Macs where Vision's accurate model can't run, Read Text always failed.
    @Test func fallsBackWhenThePrimaryThrows() async throws {
        let recognizer = FallbackTextRecognizer(primary: Stub(result: .failure(TestError())), fallback: Stub(result: .success("fast")))
        #expect(try await recognizer.recognizeText(in: image) == "fast")
    }

    @Test func throwsWhenBothFail() async {
        let recognizer = FallbackTextRecognizer(primary: Stub(result: .failure(TestError())), fallback: Stub(result: .failure(TestError())))
        await #expect(throws: TestError.self) { try await recognizer.recognizeText(in: image) }
    }
}
