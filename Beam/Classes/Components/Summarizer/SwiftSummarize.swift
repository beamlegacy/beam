import CoreServices
import Foundation

/// Wraps CoreServices SKSummary
public struct Summary: Codable, Equatable {
    public let input: String
    public let sentenceCount: Int
    public let paragraphCount: Int

    public let output: String
    public let numSentencesInSummary: Int

    /// Create summary from input
    /// - Parameters:
    ///   - input: Full lengh text
    ///   - numberOfSentences: Size of summary by number of sentences
    public init(_ input: String, numberOfSentences: Int) {
        self.input = input
        self.numSentencesInSummary = numberOfSentences
        let summary = SKSummaryCreateWithString(input as CFString).takeRetainedValue()
        self.sentenceCount = SKSummaryGetSentenceCount(summary)
        self.paragraphCount = SKSummaryGetParagraphCount(summary)

        // Check number of sentences in output to avoid crashing...
        if sentenceCount > 0 {
            self.output = SKSummaryCopySentenceSummaryString(summary, numSentencesInSummary).takeRetainedValue() as String
        } else {
            self.output = input
        }
    }

    /// Create summary from input
    /// - Parameters:
    ///   - input: Full length text
    ///   - percent: Size of the summary in percent of input text
    public init(_ input: String, percent: CGFloat) {
        self.input = input
        let summary = SKSummaryCreateWithString(input as CFString).takeRetainedValue()
        self.sentenceCount = SKSummaryGetSentenceCount(summary)
        print(percent.description)
        self.numSentencesInSummary = Int(max(1, ((CGFloat(sentenceCount)/100)*percent)))
        self.paragraphCount = SKSummaryGetParagraphCount(summary)
        print(numSentencesInSummary.description)

        // Check number of sentences in output to avoid crashing...
        if sentenceCount > 0 {
            self.output = SKSummaryCopySentenceSummaryString(summary, numSentencesInSummary).takeRetainedValue() as String
        } else {
            self.output = input
        }
    }
}

public extension String {
    /// Uses Summary type to generate summary from string
    /// - Parameter numberOfSentences: Size of summary by number of sentences
    /// - Returns: Summarized output string
    func summarize(numberOfSentences: Int) -> String {
        Summary(self, numberOfSentences: numberOfSentences).output
    }

    /// Uses Summary type to generate summary from string
    /// - Parameter percent: Size of the summary in percent of input text
    /// - Returns: Summarized output string
    func summarize(percent: CGFloat) -> String {
        Summary(self, percent: percent).output
    }
}
