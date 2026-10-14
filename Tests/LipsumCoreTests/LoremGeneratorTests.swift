import XCTest
@testable import LipsumCore

final class LoremGeneratorTests: XCTestCase {
    func testSentenceShape() {
        for _ in 0..<200 {
            let sentence = LoremGenerator.sentence()
            XCTAssertTrue(sentence.hasSuffix("."))
            XCTAssertEqual(sentence.first.map { $0.isUppercase }, true)
            let wordCount = sentence.split(separator: " ").count
            XCTAssertTrue(LoremGenerator.sentenceWordRange.contains(wordCount), "Got \(wordCount) words")
        }
    }

    func testParagraphSentenceCount() {
        for _ in 0..<200 {
            let paragraph = LoremGenerator.paragraph()
            let sentences = paragraph.filter { $0 == "." }.count
            XCTAssertTrue(LoremGenerator.paragraphSentenceRange.contains(sentences), "Got \(sentences) sentences")
        }
    }
}
