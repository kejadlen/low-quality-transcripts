# Cooking Issues transcripts

Transcripts of the [Cooking Issues](https://heritageradionetwork.org/series/cooking-issues/) podcast, hosted by Dave Arnold on Heritage Radio Network. Transcribed locally using swappable transcription backends.

## How it works

A Rake pipeline downloads episodes from the RSS feed, transcribes audio to JSON, and renders readable text. Each transcriber is a self-contained class that registers its own Rake tasks for setup and dependencies.

```
RSS feed → download audio → transcribe (JSON) → render (text)
```

## Transcribers

Set the backend with `TRANSCRIBER=name`. Each transcriber writes a JSON file with its native output format, then renders it to timestamped, paragraphed text.

| Name | Engine | Diarization | Notes |
|------|--------|-------------|-------|
| `whisper-cpp-large` | whisper.cpp (large-v3-turbo) | No | Default. Fast on Apple Silicon via Metal. |
| `whisper-cpp-tdrz` | whisper.cpp (small.en-tdrz) | tinydiarize | Lightweight model with basic speaker turns. |
| `sous_chef` | Apple SpeechAnalyzer | No | macOS 26+ only. Word-level segments. |
| `mlx` | mlx-whisper | No | Runs on Apple Silicon via MLX. |
| `mlx-diarize` | mlx-whisper + pyannote | Yes | Speaker labels via pyannote. Requires HF token. |
| `whisperx` | WhisperX | Yes | CPU-based, uses pyannote for diarization. |

## Usage

```sh
# Transcribe a single episode
rake transcribe[42]

# Transcribe all episodes
rake sync

# Re-transcribe (deletes existing JSON and text, then rebuilds)
rake retranscribe[42]

# List episodes and their transcription status
rake episodes

# Use a different transcriber
TRANSCRIBER=mlx rake transcribe[1]
```

Transcribers that use pyannote for diarization (`mlx-diarize`, `whisperx`) need a Hugging Face token with access to the [pyannote/speaker-diarization-3.1](https://hf.co/pyannote/speaker-diarization-3.1) and [pyannote/segmentation-3.0](https://hf.co/pyannote/segmentation-3.0) gated models:

```sh
export HUGGING_FACE_TOKEN=hf_...
```

## Output

Transcripts live in `transcripts/<transcriber>/`, with a JSON file (full transcription data) and a text file (rendered for reading) per episode:

```
transcripts/whisper-cpp-large/001-episode-1-cooking-issues-debuts.json
transcripts/whisper-cpp-large/001-episode-1-cooking-issues-debuts.txt
```

The text renderer groups segments into paragraphs based on silence gaps between them. The gap threshold varies by transcriber since some produce sentence-level segments and others produce word-level segments.

## Requirements

- Ruby 3.x with Bundler
- At least one transcriber's dependencies:
  - **whisper-cpp**: `whisper-cli` (install via Homebrew or build from source)
  - **sous_chef**: macOS 26+, Xcode 26+ (builds automatically)
  - **mlx / mlx-diarize**: Python 3.10+, [uv](https://github.com/astral-sh/uv) (dependencies managed automatically via inline script metadata)
  - **whisperx**: Python 3.10+, uv
