import ArgumentParser
import AVFoundation
import Foundation
import Speech

@main
struct SousChef: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Transcribe a podcast audio file using SpeechAnalyzer."
    )

    @Argument(help: "Path to the input audio file.")
    var input: String

    @Argument(help: "Path to write the output transcript.")
    var output: String

    func run() async throws {
        let inputURL = URL(fileURLWithPath: input)
        let outputURL = URL(fileURLWithPath: output)

        // Set up the transcriber.
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
            throw TranscriptionError.unsupportedLocale
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)

        // Install assets if needed.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            log("Downloading assets...")
            try await request.downloadAndInstall()
        }

        // Open the audio file.
        let audioFile = try AVAudioFile(forReading: inputURL)

        // Create the analyzer.
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Collect results in a separate task.
        let resultsTask = Task {
            var segments: [Segment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                let timeRange = Self.extractTimeRange(result.text)
                let alternatives = result.alternatives.map { String($0.characters) }
                let segment = Segment(
                    text: text,
                    start: timeRange?.start,
                    end: timeRange?.end,
                    alternatives: alternatives.isEmpty ? nil : alternatives
                )
                segments.append(segment)
                log("  [\(segment.startFormatted)] \(text)")
            }
            return segments
        }

        // Run the analysis.
        log("Transcribing \(inputURL.lastPathComponent)...")
        let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)

        // Finalize.
        if let lastSampleTime {
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let segments = try await resultsTask.value

        // Write JSON output.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(segments)
        try data.write(to: outputURL)

        log("Done. Wrote \(segments.count) segments to \(output).")
    }

    /// Extract the time range from the first audioTimeRange attribute in the result text.
    private static func extractTimeRange(_ text: AttributedString) -> (start: Double, end: Double)? {
        for run in text.runs {
            if let timeRange = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                let start = CMTimeGetSeconds(timeRange.start)
                let end = CMTimeGetSeconds(timeRange.start + timeRange.duration)
                return (start, end)
            }
        }
        return nil
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

struct Segment: Encodable {
    let text: String
    let start: Double?
    let end: Double?
    let alternatives: [String]?

    var startFormatted: String {
        guard let start else { return "?:??" }
        let total = Int(start)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

enum TranscriptionError: Error, CustomStringConvertible {
    case unsupportedLocale

    var description: String {
        switch self {
        case .unsupportedLocale:
            "en-US is not supported on this device."
        }
    }
}
