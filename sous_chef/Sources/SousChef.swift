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

    @Argument(help: "Path to write the output JSON transcript.")
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
        var segments: [Segment] = []
        let resultsTask = Task {
            var collected: [Segment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                let timeRange = extractTimeRange(from: result.text)
                collected.append(Segment(text: text, start: timeRange?.start, end: timeRange?.end))
                log("  \(text)")
            }
            return collected
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

        segments = try await resultsTask.value

        // Write JSON output.
        let transcript = Transcript(segments: segments)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(transcript)
        try data.write(to: outputURL)

        log("Done. Wrote \(segments.count) segments to \(output).")
    }

    private func extractTimeRange(from text: AttributedString) -> (start: Double, end: Double)? {
        // Walk the attributed string looking for time range attributes.
        var earliest: Double?
        var latest: Double?

        for run in text.runs {
            if let timeRange = run.audioTimeRange {
                let start = CMTimeGetSeconds(timeRange.start)
                let end = CMTimeGetSeconds(timeRange.start + timeRange.duration)
                if earliest == nil || start < earliest! { earliest = start }
                if latest == nil || end > latest! { latest = end }
            }
        }

        guard let start = earliest, let end = latest else { return nil }
        return (start, end)
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
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

struct Transcript: Encodable {
    let segments: [Segment]
}

struct Segment: Encodable {
    let text: String
    let start: Double?
    let end: Double?
}
