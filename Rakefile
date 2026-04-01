require "fileutils"
require "net/http"
require "uri"
require_relative "lib/feed"
require_relative "lib/sync"

CACHE_DIR = "cache"
AUDIO_DIR = "audio"
TRANSCRIPTS_DIR = "transcripts"
HRN_FEED = File.join(CACHE_DIR, "hrn_feed.xml")
HRN_FEED_URL = "https://rss.art19.com/cooking-issues"

directory CACHE_DIR

file HRN_FEED => CACHE_DIR do
  puts "Downloading HRN feed..."
  uri = URI(HRN_FEED_URL)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  File.write(HRN_FEED, response.body)
end

def episodes
  @episodes ||= CookingIssues::Feed.parse(HRN_FEED)
end

# --- Tasks ---

task default: :sync

desc "Fetch the feed, download episodes missing transcripts"
task sync: HRN_FEED do
  puts "Found #{episodes.size} episodes in feed."

  sync = CookingIssues::Sync.new(episodes)
  sync.run
end

desc "List all episodes from the feed"
task episodes: HRN_FEED do
  episodes.sort_by(&:number).each do |ep|
    status = Dir.glob(File.join(TRANSCRIPTS_DIR, "#{ep.slug}.*")).any? ? "✓" : " "
    puts "[#{status}] #{ep.slug}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] => HRN_FEED do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  ep = episodes.find { |e| e.number == args[:number].to_i }
  abort "Episode #{args[:number]} not found in feed." unless ep

  audio = File.join(AUDIO_DIR, "#{ep.slug}.mp3")
  abort "Audio not found: #{audio}\nRun `rake sync` first." unless File.exist?(audio)

  transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
  if File.exist?(transcript)
    puts "Already transcribed: #{ep.slug}"
    exit
  end

  FileUtils.mkdir_p(TRANSCRIPTS_DIR)
  puts "TODO: transcribe #{ep.number}. #{ep.title}"
  puts "  audio: #{audio}"
  puts "  transcript: #{transcript}"
end
