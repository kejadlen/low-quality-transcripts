# Cooking Issues transcripts

Transcripts of the [Cooking Issues](https://heritageradionetwork.org/series/cooking-issues/) podcast, hosted by Dave Arnold on Heritage Radio Network. Transcribed locally on macOS using Apple's [SpeechAnalyzer](https://developer.apple.com/documentation/speechanalyzer) framework. This project covers transcription only — search is planned separately.

## How it works

A Ruby harness pulls episodes from two podcast feeds, and a Swift CLI transcribes the audio. Transcripts are committed to this repo as flat files, one per episode.

The pipeline looks like this:

```
Feed (RSS) → Ruby harness → Swift transcriber → transcript files
```

### Feeds

Episodes come from two sources:

- Heritage Radio Network: https://heritageradionetwork.org/series/cooking-issues/
- Patreon (private feed)

### Components

The Ruby harness manages the pipeline: fetching RSS feeds, downloading episodes, invoking the transcriber, and organizing output.

The Swift CLI accepts an audio file and writes a transcript using SpeechAnalyzer. It runs as a standalone command-line tool that the Ruby harness shells out to.

### Output

Transcripts live in this repo, one file per episode. The output format is not yet determined — we'll use whatever structure SpeechAnalyzer provides and refine from there.

## Requirements

- macOS 26 or later (SpeechAnalyzer requires macOS Tahoe)
- Xcode 26 or later
- Ruby 3.x

## Status

Early development.
