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

def episodes
  @episodes ||= CookingIssues::Feed.parse(HRN_FEED)
end

def define_episode_tasks
  episodes.sort_by(&:number).each do |ep|
    audio = File.join(AUDIO_DIR, "#{ep.slug}.mp3")
    transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")

    file audio => AUDIO_DIR do
      puts "Downloading #{ep.slug}..."
      CookingIssues::Download.fetch(ep.audio_url, audio)
    end

    file transcript => [audio, TRANSCRIPTS_DIR] do
      puts "Transcribing #{ep.number}. #{ep.title}..."
      puts "  TODO: sous_chef #{audio} #{transcript}"
    end
  end
end

# Parse the feed and register file tasks once it exists.
task setup: HRN_FEED do
  define_episode_tasks
end

# --- Tasks ---

task default: :sync

desc "Download and transcribe all episodes"
task sync: :setup do
  episodes.sort_by(&:number).each do |ep|
    transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
    Rake::Task[transcript].invoke
  end
end

desc "List all episodes from the feed"
task episodes: :setup do
  episodes.sort_by(&:number).each do |ep|
    status = File.exist?(File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")) ? "✓" : " "
    puts "[#{status}] #{ep.slug}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] => :setup do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  ep = episodes.find { |e| e.number == args[:number].to_i }
  abort "Episode #{args[:number]} not found in feed." unless ep

  transcript = File.join(TRANSCRIPTS_DIR, "#{ep.slug}.json")
  Rake::Task[transcript].invoke
end
