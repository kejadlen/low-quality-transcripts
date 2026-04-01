require "net/http"
require "pathname"
require "uri"
require_relative "lib/feed"
require_relative "lib/download"

CACHE_DIR = Pathname("cache")
AUDIO_DIR = CACHE_DIR / "audio"
TRANSCRIPTS_DIR = Pathname("transcripts")
SOUS_CHEF = Pathname("sous_chef/.build/release/sous_chef")
HRN_FEED = CACHE_DIR / "hrn_feed.xml"
HRN_FEED_URL = "https://rss.art19.com/cooking-issues"
TRANSCRIBER = ENV.fetch("TRANSCRIBER", "whisperx")
WHISPER_MODEL = ENV.fetch("WHISPER_MODEL", "large-v3-turbo")
MODELS_DIR = CACHE_DIR / "models"
DOWNLOAD_SCRIPT = CACHE_DIR / "download-ggml-model.sh"
DOWNLOAD_SCRIPT_URL = "https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/models/download-ggml-model.sh"

directory CACHE_DIR.to_s
directory AUDIO_DIR.to_s
directory MODELS_DIR.to_s

file HRN_FEED.to_s => CACHE_DIR.to_s do
  puts "Downloading HRN feed..."
  uri = URI(HRN_FEED_URL)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  HRN_FEED.write(response.body)
end

file SOUS_CHEF.to_s do
  sh "cd sous_chef && swift build -c release"
end

file DOWNLOAD_SCRIPT.to_s => CACHE_DIR.to_s do
  puts "Downloading whisper model script..."
  CookingIssues::Download.fetch(DOWNLOAD_SCRIPT_URL, DOWNLOAD_SCRIPT.to_s)
  chmod DOWNLOAD_SCRIPT.to_s, 0o755
end

desc "Download a whisper.cpp GGML model (default: large-v3-turbo, override with WHISPER_MODEL)"
task :model, [:name] => [DOWNLOAD_SCRIPT.to_s, MODELS_DIR.to_s] do |_t, args|
  model = args[:name] || WHISPER_MODEL
  sh DOWNLOAD_SCRIPT.to_s, model, MODELS_DIR.to_s
end

Rake::Task[HRN_FEED.to_s].invoke

EPISODES = CookingIssues::Feed.parse(HRN_FEED)

def transcribe(ep, audio_path, transcript_path)
  case TRANSCRIBER
  when "whisperx"
    hf_token = ENV.fetch("HUGGING_FACE_TOKEN") { abort "Set HUGGING_FACE_TOKEN for diarization." }
    sh "whisperx", audio_path,
      "--model", "large-v3",
      "--compute_type", "int8",
      "--device", "cpu",
      "--diarize", "--hf_token", hf_token,
      "--output_dir", File.dirname(transcript_path),
      "--output_format", "txt"
  when "whisper-cpp-large"
    model_path = MODELS_DIR / "ggml-large-v3-turbo.bin"
    Rake::Task[:model].invoke("large-v3-turbo") unless model_path.exist?
    sh "whisper-cpp", "--model", model_path.to_s, "--tdrz", "--output-txt", "--output-file", transcript_path.delete_suffix(".txt"), audio_path
  when "whisper-cpp-tdrz"
    model_path = MODELS_DIR / "ggml-small.en-tdrz.bin"
    Rake::Task[:model].invoke("small.en-tdrz") unless model_path.exist?
    sh "whisper-cpp", "--model", model_path.to_s, "--tdrz", "--output-txt", "--output-file", transcript_path.delete_suffix(".txt"), audio_path
  when "sous_chef"
    Rake::Task[SOUS_CHEF.to_s].invoke
    sh SOUS_CHEF.to_s, audio_path, transcript_path
  else
    abort "Unknown transcriber: #{TRANSCRIBER}. Use 'whisperx', 'whisper-cpp-large', 'whisper-cpp-tdrz', or 'sous_chef'."
  end
end

EPISODES.values.each do |ep|
  transcript_dir = (TRANSCRIPTS_DIR / TRANSCRIBER).to_s
  directory transcript_dir

  file ep.audio_path => AUDIO_DIR.to_s do
    puts "Downloading #{ep.slug}..."
    CookingIssues::Download.fetch(ep.audio_url, ep.audio_path)
  end

  file ep.transcript_path(TRANSCRIBER) => [ep.audio_path, transcript_dir] do
    transcribe(ep, ep.audio_path, ep.transcript_path(TRANSCRIBER))
  end
end

# --- Tasks ---

task default: :sync

desc "Download and transcribe all episodes"
task :sync do
  # The feed is reverse-chronological; process oldest episodes first.
  EPISODES.values.sort_by(&:number).each do |ep|
    Rake::Task[ep.transcript_path(TRANSCRIBER)].invoke
  end
end

desc "List all episodes from the feed"
task :episodes do
  EPISODES.values.sort_by(&:number).each do |ep|
    status = Pathname(ep.transcript_path(TRANSCRIBER)).exist? ? "✓" : " "
    puts "[#{status}] #{ep.slug}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  Rake::Task[ep.transcript_path(TRANSCRIBER)].invoke
end

desc "Re-transcribe an episode (e.g., rake retranscribe[42])"
task :retranscribe, [:number] do |_t, args|
  abort "Usage: rake retranscribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  path = Pathname(ep.transcript_path(TRANSCRIBER))
  path.delete if path.exist?
  Rake::Task[ep.transcript_path(TRANSCRIBER)].reenable
  Rake::Task[ep.transcript_path(TRANSCRIBER)].invoke
end
