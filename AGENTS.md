# Agents

## Project overview

Podcast transcript pipeline for Cooking Issues with Dave Arnold.
Downloads episodes from two RSS feeds (Heritage Radio Network and
Acast), transcribes audio through swappable backends, renders
timestamped text, and generates a static site with full-text search
via Pagefind.

## Architecture

```
lib/config.rb        — Config data class, all paths and URLs
lib/feed.rb          — Episode data class, RSS feed parser
lib/episode_task.rb  — Per-episode path derivation (slug, audio, JSON, text)
lib/transcribers.rb  — Transcriber classes (resolve, register, call, render)
lib/download.rb      — HTTP download helper with redirect following
lib/pages/           — ERB templates for the static site
bin/                  — Self-contained uv Python scripts (mlx-transcribe, parakeet-transcribe)
Rakefile              — Pipeline orchestration, tasks
```

## Pipeline

Each episode flows through: audio download → JSON transcription →
text rendering. The JSON is an intermediate artifact stored in
`cache/<transcriber>/`. The rendered text lives in
`transcripts/<transcriber>/` and is committed to the repo. The
static site is generated from the text files and is not committed.

## Transcribers

Each transcriber is a class in `lib/transcribers.rb` inheriting from
`Transcribers::Base`. The interface:

- `name` — directory name for output
- `prereqs` — file paths the transcript task depends on
- `register` — define Rake file tasks for setup (model downloads, builds)
- `call(audio_path, transcript_path)` — run transcription, produce JSON
- `render(json_path, txt_path)` — convert JSON to readable text

Transcribers that don't need setup must still override `register` with
a no-op — the base class raises `NotImplementedError`.

The whisper-cpp transcribers take `cache_dir` in their constructor for
model paths. Others use no constructor arguments.

## Conventions

- `Config.from_env` builds all configuration from env vars and defaults.
  Don't scatter `ENV.fetch` calls or hardcoded paths through the codebase.
- `EpisodeTask` wraps an episode and its index. Use it instead of
  passing `(index, ep)` pairs.
- Python scripts in `bin/` are self-contained uv scripts with inline
  dependency metadata. They handle their own virtualenvs.
- Transcription JSON formats vary by backend — each transcriber's
  `render` method knows its own format.
- Paragraph splitting heuristics differ per transcriber. Some use
  silence gaps, some use sentence counts.

## Tasks

| Task | Description |
|------|-------------|
| `rake sync` | Download, transcribe, and render all episodes |
| `rake episodes` | List episodes with transcription status |
| `rake transcribe[N]` | Transcribe a single episode by number |
| `rake retranscribe[N]` | Re-transcribe from scratch |
| `rake html` | Generate HTML transcript pages |
| `rake pagefind` | Index pages for search with Pagefind |
| `rake serve` | Build and serve the site locally on port 8000 |
