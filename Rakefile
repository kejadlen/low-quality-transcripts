require "json"
require "net/http"
require "pathname"
require "uri"

require_relative "lib/feed"
require_relative "lib/download"

# --- Configuration ---

CACHE_DIR = Pathname("cache")
AUDIO_DIR = CACHE_DIR / "audio"
TRANSCRIPTS_DIR = Pathname("transcripts")

HRN_FEED = CACHE_DIR / "hrn_feed.xml"
HRN_FEED_URL = "https://rss.art19.com/cooking-issues"

PATREON_FEED = CACHE_DIR / "patreon_feed.xml"
PATREON_FEED_URL = ENV.fetch("PATREON_FEED_URL")

load File.expand_path("lib/tasks/transcribers.rake", __dir__)

TRANSCRIBER = Transcribers.resolve(ENV.fetch("TRANSCRIBER", "sous_chef"))
TRANSCRIBER.register

TRANSCRIBER_CACHE_DIR = CACHE_DIR / TRANSCRIBER.name
TEXT_DIR = TRANSCRIPTS_DIR / TRANSCRIBER.name

# --- Path helpers ---

def episode_slug(index, ep)
  format("%03d-%s", index + 1, ep.slug)
end

def audio_path(index, ep)
  (AUDIO_DIR / "#{episode_slug(index, ep)}.mp3").to_s
end

def transcript_path(index, ep)
  (TRANSCRIBER_CACHE_DIR / "#{episode_slug(index, ep)}.json").to_s
end

def text_path(index, ep)
  (TEXT_DIR / "#{episode_slug(index, ep)}.txt").to_s
end

# --- Feed downloads ---

directory CACHE_DIR.to_s
directory AUDIO_DIR.to_s
directory TRANSCRIBER_CACHE_DIR.to_s
directory TEXT_DIR.to_s

file HRN_FEED.to_s => CACHE_DIR.to_s do
  puts "Downloading HRN feed..."
  uri = URI(HRN_FEED_URL)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  HRN_FEED.write(response.body)
end

file PATREON_FEED.to_s => CACHE_DIR.to_s do
  puts "Downloading Patreon feed..."
  CookingIssues::Download.fetch(PATREON_FEED_URL, PATREON_FEED.to_s)
end

Rake::Task[HRN_FEED.to_s].invoke
Rake::Task[PATREON_FEED.to_s].invoke

EPISODES = CookingIssues::Feed.parse(HRN_FEED) + CookingIssues::Feed.parse(PATREON_FEED)

# --- Per-episode file tasks ---

EPISODES.each_with_index do |ep, i|
  audio = audio_path(i, ep)
  transcript = transcript_path(i, ep)
  txt = text_path(i, ep)

  file audio => AUDIO_DIR.to_s do
    puts "Downloading #{episode_slug(i, ep)}..."
    CookingIssues::Download.fetch(ep.audio_url, audio)
  end

  file transcript => [audio, TRANSCRIBER_CACHE_DIR.to_s, *TRANSCRIBER.prereqs] do
    TRANSCRIBER.call(audio, transcript)
  end

  file txt => [transcript, TEXT_DIR.to_s] do
    TRANSCRIBER.render(transcript, txt)
  end
end

# --- Tasks ---

task default: :sync

desc "Download, transcribe, and render all episodes"
task :sync do
  EPISODES.each_with_index do |ep, i|
    Rake::Task[text_path(i, ep)].invoke
  end
end

desc "List all episodes from the feed"
task :episodes do
  EPISODES.each_with_index do |ep, i|
    status = Pathname(text_path(i, ep)).exist? ? "✓" : " "
    puts "[#{status}] #{episode_slug(i, ep)}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  i = args[:number].to_i - 1
  ep = EPISODES.fetch(i) { abort "Episode #{args[:number]} not found in feed." }

  Rake::Task[text_path(i, ep)].invoke
end

desc "Re-transcribe an episode (e.g., rake retranscribe[42])"
task :retranscribe, [:number] do |_t, args|
  abort "Usage: rake retranscribe[NUMBER]" unless args[:number]

  i = args[:number].to_i - 1
  ep = EPISODES.fetch(i) { abort "Episode #{args[:number]} not found in feed." }

  json = Pathname(transcript_path(i, ep))
  txt = Pathname(text_path(i, ep))
  json.delete if json.exist?
  txt.delete if txt.exist?
  Rake::Task[text_path(i, ep)].reenable
  Rake::Task[transcript_path(i, ep)].reenable
  Rake::Task[text_path(i, ep)].invoke
end

load File.expand_path("lib/tasks/site.rake", __dir__)
