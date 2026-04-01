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
            var lines: [String] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                let timestamp = Self.formatTimestamp(result.text)
                let line = "[\(timestamp)] \(text)"
                lines.append(line)
                log("  \(line)")
            }
            return lines
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

        let lines = try await resultsTask.value

        // Write timestamped transcript.
        let text = lines.joined(separator: "\n")
        try text.write(to: outputURL, atomically: true, encoding: .utf8)

        log("Done. Wrote \(lines.count) segments to \(output).")
    }

    /// Extract the start time from the first audioTimeRange attribute in the result text.
    private static func formatTimestamp(_ text: AttributedString) -> String {
        for run in text.runs {
            if let timeRange = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                let seconds = CMTimeGetSeconds(timeRange.start)
                let h = Int(seconds) / 3600
                let m = (Int(seconds) % 3600) / 60
                let s = Int(seconds) % 60
                return h > 0
                    ? String(format: "%d:%02d:%02d", h, m, s)
                    : String(format: "%d:%02d", m, s)
            }
        }
        return "?:??"
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
