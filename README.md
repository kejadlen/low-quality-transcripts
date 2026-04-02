# Cooking Issues transcripts

Transcripts of the [Cooking Issues](https://heritageradionetwork.org/series/cooking-issues/) podcast, hosted by Dave Arnold. Transcribed locally using swappable backends, searchable via a static site.

## How it works

A Rake pipeline pulls episodes from two RSS feeds (Heritage Radio Network and [Acast](https://shows.acast.com/cooking-issues-with-dave-arnold)), transcribes audio to JSON, renders readable text, and generates a searchable static site with [Pagefind](https://pagefind.app).

```
RSS feeds → download audio → transcribe (JSON) → render (text) → static site
```

## Transcribers

Set the backend with `TRANSCRIBER=name`.

| Name | Engine | Diarization | Notes |
|------|--------|-------------|-------|
| `parakeet` | Parakeet TDT via parakeet-mlx | No | Fast on Apple Silicon. |
| `whisper-cpp-large` | whisper.cpp (large-v3-turbo) | No | Fast on Apple Silicon via Metal. |
| `whisper-cpp-tdrz` | whisper.cpp (small.en-tdrz) | tinydiarize | Lightweight with basic speaker turns. |
| `sous_chef` | Apple SpeechAnalyzer | No | macOS 26+ only. Word-level segments. |
| `mlx` | mlx-whisper | No | Apple Silicon via MLX. |
| `mlx-diarize` | mlx-whisper + pyannote | Yes | Speaker labels. Requires HF token. |
| `whisperx` | WhisperX | Yes | CPU-based with pyannote diarization. |

## Usage

```sh
# Transcribe a single episode
rake transcribe[42]

# Transcribe all episodes
rake sync

# Re-transcribe from scratch
rake retranscribe[42]

# List episodes with transcription status
rake episodes

# Use a different transcriber
TRANSCRIBER=parakeet rake transcribe[1]

# Generate the searchable static site
rake pages

# Build and serve locally
rake serve
```

Transcribers that use pyannote (`mlx-diarize`, `whisperx`) need a Hugging Face token with access to the [pyannote/speaker-diarization-3.1](https://hf.co/pyannote/speaker-diarization-3.1) and [pyannote/segmentation-3.0](https://hf.co/pyannote/segmentation-3.0) gated models:

```sh
export HUGGING_FACE_TOKEN=hf_...
```

## Output

Intermediate JSON goes to `cache/<transcriber>/`. Rendered text is committed to `transcripts/<transcriber>/`, one file per episode:

```
transcripts/parakeet/001-episode-1-cooking-issues-debuts.txt
```

The text renderer groups segments into paragraphs. The heuristic varies by transcriber — silence gaps for most, sentence counts for Parakeet (whose chunking overlap produces overlapping timestamps).

## Static site

`rake pages` generates a static site in `pages/` with one HTML page per episode and a Pagefind search index. `rake serve` builds and serves it locally on port 8000. GitHub Actions deploys it to GitHub Pages on push to main.

## Requirements

- Ruby 3.x with Bundler
- Python 3.10+ with [uv](https://github.com/astral-sh/uv) (for Parakeet, MLX, and Pagefind)
- At least one transcriber's dependencies:
  - **parakeet**: uv (dependencies managed automatically)
  - **whisper-cpp**: `whisper-cli` (Homebrew or build from source)
  - **sous_chef**: macOS 26+, Xcode 26+ (builds automatically)
  - **mlx / mlx-diarize / whisperx**: uv
