require "fileutils"
require "net/http"
require "uri"
require_relative "lib/feed"
require_relative "lib/download"

CACHE_DIR = "cache"
AUDIO_DIR = "audio"
TRANSCRIPTS_DIR = "transcripts"
HRN_FEED = File.join(CACHE_DIR, "hrn_feed.xml")
HRN_FEED_URL = "https://rss.art19.com/cooking-issues"

directory CACHE_DIR
directory AUDIO_DIR
directory TRANSCRIPTS_DIR

file HRN_FEED => CACHE_DIR do
  puts "Downloading HRN feed..."
  uri = URI(HRN_FEED_URL)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  File.write(HRN_FEED, response.body)
end

Rake::Task[HRN_FEED].invoke

EPISODES = CookingIssues::Feed.parse(HRN_FEED)

EPISODES.values.each do |ep|
  audio = File.join(AUDIO_DIR, "#{ep.slug}.mp3")
  file audio => AUDIO_DIR do
    puts "Downloading #{ep.slug}..."
    CookingIssues::Download.fetch(ep.audio_url, audio)
  end

  transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
  file transcript => [audio, TRANSCRIPTS_DIR] do
    puts "Transcribing #{ep.number}. #{ep.title}..."
    puts "  TODO: sous_chef #{audio} #{transcript}"
  end
end

# --- Tasks ---

task default: :sync

desc "Download and transcribe all episodes"
task :sync do
  EPISODES.values.each do |ep|
    transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
    Rake::Task[transcript].invoke
  end
end

desc "List all episodes from the feed"
task :episodes do
  EPISODES.values.each do |ep|
    status = File.exist?(File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")) ? "✓" : " "
    puts "[#{status}] #{ep.slug}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
  Rake::Task[transcript].invoke
end

desc "Re-transcribe an episode (e.g., rake retranscribe[42])"
task :retranscribe, [:number] do |_t, args|
  abort "Usage: rake retranscribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
  FileUtils.rm_f(transcript)
  Rake::Task[transcript].reenable
  Rake::Task[transcript].invoke
end
