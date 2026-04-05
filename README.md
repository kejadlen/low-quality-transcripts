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

## Why Parakeet

I run everything locally on a MacBook Pro, which is the primary constraint. That rules out most heavyweight transcription pipelines and anything that requires more GPU than Apple Silicon provides.

Apple's SpeechAnalyzer (`sous_chef`) is the fastest option, but Parakeet produces noticeably better transcripts — based on informal comparison of a handful of episodes, not a rigorous benchmark. Most of the other backends (WhisperX, mlx-whisper with diarization) were too resource-intensive to run comfortably on the same machine.

There are multiple transcriber backends wired up so it's easy to re-evaluate as models and hardware improve. The transcriber table above reflects what's implemented, not what's practical to run at scale on a single laptop.

Solutions don't need to stay local — cloud APIs, hosted inference, and CI-based pipelines are all welcome. I'm not looking to purchase or rent hardware for this, but I'm open to other approaches.

## What's missing

Two features would meaningfully improve transcript quality but aren't available with the current setup.

Contextual hinting would let the transcriber bias toward domain-specific vocabulary — recurring guest names, cooking terminology (rotovap, Searzall, hydrocolloids), show-specific jargon.

Diarization so that transcripts could denote speakers. Pyannote-based diarization works (`mlx-diarize`, `whisperx`) but wasn't performant enough to run locally alongside transcription. The `whisper-cpp-tdrz` backend offers lightweight tinydiarize, but it uses a smaller model with lower transcription quality.

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

Only the rendered text files are committed to the repo, one per episode in `transcripts/<transcriber>/`:

```
transcripts/parakeet/001-episode-1-cooking-issues-debuts.txt
```

The intermediate JSON from each transcriber lives in `cache/<transcriber>/` and is ignored. These files contain word- or sentence-level timestamps and are substantially larger than the rendered text. I have them locally for re-rendering or analysis but they're not worth carrying in the repo.

The text renderer groups segments into paragraphs. The heuristic varies by transcriber — silence gaps for most, sentence counts for Parakeet (whose chunking overlap produces overlapping timestamps).

## Static site

`rake pages` generates a static site in `pages/` with one HTML page per episode and a Pagefind search index. `rake serve` builds and serves it locally on port 8000. GitHub Actions deploys it to GitHub Pages on push to main.

## Search

Beyond the Pagefind-powered static site, there are two CLI search tools for querying transcripts directly. Both index from the rendered text files and store their databases in `cache/`.

Full-text search uses SQLite FTS5 with BM25 ranking:

```sh
bin/fts-search index [transcripts/parakeet]
bin/fts-search search "agar clarification" -n 5
```

Semantic search uses sentence-transformers (`all-MiniLM-L6-v2`) with sqlite-vec for nearest-neighbor lookup:

```sh
bin/semantic-search index [transcripts/parakeet]
bin/semantic-search search "how to clarify juice" -n 5
```

Full-text search is fast and needs only SQLite. Semantic search is better for fuzzy or conceptual queries but requires downloading the embedding model on first run.

## Requirements

- Ruby 3.x with Bundler
- Python 3.10+ with [uv](https://github.com/astral-sh/uv) (for Parakeet, MLX, and Pagefind)
- At least one transcriber's dependencies:
  - parakeet — uv (dependencies managed automatically)
  - whisper-cpp — `whisper-cli` (Homebrew or build from source)
  - sous_chef — macOS 26+, Xcode 26+ (builds automatically)
  - mlx, mlx-diarize, whisperx — uv
