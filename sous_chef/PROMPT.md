# sous_chef

A command-line tool that transcribes a podcast audio file using Apple's
SpeechAnalyzer framework (macOS 26+, Speech framework).

## Usage

```
sous_chef <input.mp3> <output.json>
```

Reads an audio file, transcribes it using SpeechAnalyzer with the
SpeechTranscriber module, and writes the results as JSON.

## SpeechAnalyzer API overview

The Speech framework on macOS 26 introduces `SpeechAnalyzer`, an actor
that coordinates analysis modules against audio input. The module we
care about is `SpeechTranscriber`, which does speech-to-text.

### Key types

- `SpeechAnalyzer` — the actor that drives analysis. Accepts modules
  and audio input, controls the session lifecycle.
- `SpeechTranscriber` — a module that produces transcription results.
  Created with a locale and a preset.
- `SpeechTranscriber.Preset` — predefined configurations. The relevant
  ones for offline file transcription:
  - `.transcription` — basic accurate transcription, no timestamps
  - `.timeIndexedTranscriptionWithAlternatives` — transcription with
    audio time ranges and alternative interpretations
- `SpeechTranscriber.Result` — a phrase of transcribed speech. Has:
  - `.text` — an `AttributedString` with the best interpretation. Can
    carry `audioTimeRange` attributes when the preset includes them.
  - `.alternatives` — alternative interpretations in descending
    likelihood order.
- `AssetInventory` — manages ML model downloads. Assets must be
  installed before transcription can begin.
- `AnalyzerInput` — wraps an `AVAudioPCMBuffer` for the input sequence.

### File-based transcription flow

The simplest path for transcribing a file:

```swift
import Speech
import AVFoundation

// 1. Create the transcriber module.
guard let locale = SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
    fatalError("en-US not supported")
}
let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)

// 2. Ensure assets are installed.
if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    try await request.downloadAndInstall()
}

// 3. Open the audio file.
let audioFile = try AVAudioFile(forReading: URL(fileURLWithPath: inputPath))

// 4. Create the analyzer and feed it the file.
let analyzer = SpeechAnalyzer(modules: [transcriber])
let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)

// 5. Collect results concurrently.
// transcriber.results is an AsyncSequence of SpeechTranscriber.Result.
// Each result has .text (AttributedString) which you can convert to
// plain text with String(result.text.characters).
// When using timeIndexedTranscriptionWithAlternatives, the text's
// attributed string includes audioTimeRange attributes.

// 6. Finalize.
if let lastSampleTime {
    try await analyzer.finalizeAndFinish(through: lastSampleTime)
} else {
    try analyzer.cancelAndFinishNow()
}
```

Note that result collection (step 5) must happen concurrently with
analysis (step 4) — they run in separate tasks. The analyzer produces
results as it processes audio; the results stream ends after
finalization.

### Result structure

`SpeechTranscriber.Result.text` is an `AttributedString`. With the
`timeIndexedTranscriptionWithAlternatives` preset, each segment of text
carries a `SpeechAttributes.TimeRangeAttribute` indicating the audio
time range it corresponds to.

To get plain text: `String(result.text.characters)`

## Output format

Write JSON to the output path. Structure:

```json
{
  "segments": [
    {
      "text": "transcribed text for this segment",
      "start": 0.0,
      "end": 5.23
    }
  ]
}
```

Each segment corresponds to one `SpeechTranscriber.Result`. Times are
in seconds from the start of the audio file. If time range attributes
are unavailable, omit `start` and `end`.

## Build

This is a Swift package. Build with:

```
cd sous_chef
swift build -c release
```

The binary lands at `.build/release/sous_chef`.

## Implementation notes

- Use Swift 6 and strict concurrency.
- Use `ArgumentParser` for CLI argument handling.
- The tool should print progress to stderr (e.g., "Downloading
  assets...", "Transcribing...", "Done.") so stdout stays clean.
- Exit with a nonzero code on failure.
- Use `analyzeSequence(from:)` for the file-based path — it handles
  audio format conversion automatically.
- Collect results by iterating `transcriber.results` in a separate
  task started before calling `analyzeSequence(from:)`.
