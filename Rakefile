require "json"
require "net/http"
require "pathname"
require "uri"

require_relative "lib/feed"
require_relative "lib/download"

CACHE_DIR = Pathname("cache")
AUDIO_DIR = CACHE_DIR / "audio"
TRANSCRIPTS_DIR = Pathname("transcripts")
HRN_FEED = CACHE_DIR / "hrn_feed.xml"
HRN_FEED_URL = "https://rss.art19.com/cooking-issues"

directory CACHE_DIR.to_s
directory AUDIO_DIR.to_s

file HRN_FEED.to_s => CACHE_DIR.to_s do
  puts "Downloading HRN feed..."
  uri = URI(HRN_FEED_URL)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  HRN_FEED.write(response.body)
end

load File.expand_path("lib/tasks/transcribers.rake", __dir__)

TRANSCRIBER = Transcribers.resolve(ENV.fetch("TRANSCRIBER", "sous_chef"))
TRANSCRIBER.register

Rake::Task[HRN_FEED.to_s].invoke

EPISODES = CookingIssues::Feed.parse(HRN_FEED)

def audio_path(ep)
  (AUDIO_DIR / "#{ep.slug}.mp3").to_s
end

TRANSCRIBER_CACHE_DIR = CACHE_DIR / TRANSCRIBER.name

directory TRANSCRIBER_CACHE_DIR.to_s

def transcript_path(ep)
  (TRANSCRIBER_CACHE_DIR / "#{ep.slug}.json").to_s
end

def text_path(ep)
  (TRANSCRIPTS_DIR / TRANSCRIBER.name / "#{ep.slug}.txt").to_s
end

TEXT_DIR = TRANSCRIPTS_DIR / TRANSCRIBER.name

directory TEXT_DIR.to_s

EPISODES.values.each do |ep|
  audio = audio_path(ep)
  transcript = transcript_path(ep)

  file audio => AUDIO_DIR.to_s do
    puts "Downloading #{ep.slug}..."
    CookingIssues::Download.fetch(ep.audio_url, audio)
  end

  file transcript => [audio, TRANSCRIBER_CACHE_DIR.to_s, *TRANSCRIBER.prereqs] do
    TRANSCRIBER.call(audio, transcript)
  end

  txt = text_path(ep)

  file txt => [transcript, TEXT_DIR.to_s] do
    TRANSCRIBER.render(transcript, txt)
  end
end

task default: :sync

desc "Download, transcribe, and render all episodes"
task :sync do
  # The feed is reverse-chronological; process oldest episodes first.
  EPISODES.values.sort_by(&:number).each do |ep|
    Rake::Task[text_path(ep)].invoke
  end
end

desc "List all episodes from the feed"
task :episodes do
  EPISODES.values.sort_by(&:number).each do |ep|
    status = Pathname(text_path(ep)).exist? ? "✓" : " "
    puts "[#{status}] #{ep.slug}  #{ep.title}"
  end
end

desc "Transcribe an episode by number (e.g., rake transcribe[42])"
task :transcribe, [:number] do |_t, args|
  abort "Usage: rake transcribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  Rake::Task[text_path(ep)].invoke
end

desc "Move intermediate files from transcripts/ to cache/"
task :migrate_cache do
  EPISODES.values.each do |ep|
    old_path = TRANSCRIPTS_DIR / TRANSCRIBER.name / "#{ep.slug}.json"
    new_path = Pathname(transcript_path(ep))
    next unless old_path.exist?

    new_path.dirname.mkpath
    FileUtils.mv(old_path.to_s, new_path.to_s)
    puts "Moved #{old_path} → #{new_path}"
  end
end

load File.expand_path("lib/tasks/site.rake", __dir__)

desc "Re-transcribe an episode (e.g., rake retranscribe[42])"
task :retranscribe, [:number] do |_t, args|
  abort "Usage: rake retranscribe[NUMBER]" unless args[:number]

  ep = EPISODES[args[:number].to_i]
  abort "Episode #{args[:number]} not found in feed." unless ep

  json = Pathname(transcript_path(ep))
  txt = Pathname(text_path(ep))
  json.delete if json.exist?
  txt.delete if txt.exist?
  Rake::Task[text_path(ep)].reenable
  Rake::Task[transcript_path(ep)].reenable
  Rake::Task[text_path(ep)].invoke
end
