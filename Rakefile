require "json"
require "net/http"
require "pathname"
require "uri"

require_relative "lib/config"
require_relative "lib/feed"
require_relative "lib/download"

load File.expand_path("lib/tasks/transcribers.rake", __dir__)

CONFIG = CookingIssues::Config.from_env(Transcribers)
CONFIG.transcriber.register

# --- Path helpers ---

def episode_slug(index, ep)
  format("%03d-%s", index + 1, ep.slug)
end

def audio_path(index, ep)
  (CONFIG.audio_dir / "#{episode_slug(index, ep)}.mp3").to_s
end

def transcript_path(index, ep)
  (CONFIG.transcriber_cache_dir / "#{episode_slug(index, ep)}.json").to_s
end

def text_path(index, ep)
  (CONFIG.text_dir / "#{episode_slug(index, ep)}.txt").to_s
end

# --- Feed downloads ---

[CONFIG.cache_dir, CONFIG.audio_dir, CONFIG.transcriber_cache_dir, CONFIG.text_dir].each do |dir|
  directory dir.to_s
end

file CONFIG.hrn_feed_path.to_s => CONFIG.cache_dir.to_s do
  puts "Downloading HRN feed..."
  uri = URI(CONFIG.hrn_feed_url)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  CONFIG.hrn_feed_path.write(response.body)
end

file CONFIG.patreon_feed_path.to_s => CONFIG.cache_dir.to_s do
  puts "Downloading Patreon feed..."
  CookingIssues::Download.fetch(CONFIG.patreon_feed_url, CONFIG.patreon_feed_path.to_s)
end

Rake::Task[CONFIG.hrn_feed_path.to_s].invoke
Rake::Task[CONFIG.patreon_feed_path.to_s].invoke

EPISODES = CookingIssues::Feed.parse(CONFIG.hrn_feed_path) +
           CookingIssues::Feed.parse(CONFIG.patreon_feed_path)

# --- Per-episode file tasks ---

EPISODES.each_with_index do |ep, i|
  audio = audio_path(i, ep)
  transcript = transcript_path(i, ep)
  txt = text_path(i, ep)

  file audio => CONFIG.audio_dir.to_s do
    puts "Downloading #{episode_slug(i, ep)}..."
    CookingIssues::Download.fetch(ep.audio_url, audio)
  end

  file transcript => [audio, CONFIG.transcriber_cache_dir.to_s, *CONFIG.transcriber.prereqs] do
    CONFIG.transcriber.call(audio, transcript)
  end

  file txt => [transcript, CONFIG.text_dir.to_s] do
    CONFIG.transcriber.render(transcript, txt)
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
