require "json"
require "net/http"
require "pathname"
require "uri"

require_relative "lib/config"
require_relative "lib/episode_task"
require_relative "lib/feed"
require_relative "lib/download"

load File.expand_path("lib/tasks/transcribers.rake", __dir__)

CONFIG = CookingIssues::Config.from_env(Transcribers)
CONFIG.transcriber.register

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

episodes = CookingIssues::Feed.parse(CONFIG.hrn_feed_path) +
           CookingIssues::Feed.parse(CONFIG.patreon_feed_path)

EPISODE_TASKS = episodes.map.with_index do |ep, i|
  CookingIssues::EpisodeTask.new(index: i, episode: ep, config: CONFIG)
end

# --- Per-episode file tasks ---

EPISODE_TASKS.each do |et|
  file et.audio_path => CONFIG.audio_dir.to_s do
    puts "Downloading #{et.slug}..."
    CookingIssues::Download.fetch(et.episode.audio_url, et.audio_path)
  end

  file et.transcript_path => [et.audio_path, CONFIG.transcriber_cache_dir.to_s, *CONFIG.transcriber.prereqs] do
    CONFIG.transcriber.call(et.audio_path, et.transcript_path)
  end

  file et.text_path => [et.transcript_path, CONFIG.text_dir.to_s] do
    CONFIG.transcriber.render(et.transcript_path, et.text_path)
  end
end

# --- Tasks ---

task default: :sync

desc "Download, transcribe, and render all episodes"
task :sync do
  EPISODE_TASKS.each { |et| Rake::Task[et.text_path].invoke }
end

desc "List all episodes from the feed"
task :episodes do
  EPISODE_TASKS.each do |et|
    status = Pathname(et.text_path).exist? ? "✓" : " "
    puts "[#{status}] #{et.slug}  #{et.episode.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  et = EPISODE_TASKS.fetch(args[:number].to_i - 1) { abort "Episode #{args[:number]} not found in feed." }

  Rake::Task[et.text_path].invoke
end

desc "Re-transcribe an episode (e.g., rake retranscribe[42])"
task :retranscribe, [:number] do |_t, args|
  abort "Usage: rake retranscribe[NUMBER]" unless args[:number]

  et = EPISODE_TASKS.fetch(args[:number].to_i - 1) { abort "Episode #{args[:number]} not found in feed." }

  [et.transcript_path, et.text_path].each do |path|
    p = Pathname(path)
    p.delete if p.exist?
    Rake::Task[path].reenable
  end
  Rake::Task[et.text_path].invoke
end

load File.expand_path("lib/tasks/site.rake", __dir__)
