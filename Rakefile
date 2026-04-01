require "fileutils"
require "net/http"
require "uri"
require_relative "lib/feed"
require_relative "lib/sync"

CACHE_DIR = "cache"
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

task default: :sync

desc "Fetch the feed, download episodes missing transcripts"
task sync: HRN_FEED do
  feed = CookingIssues::Feed.new(HRN_FEED)
  episodes = feed.episodes
  puts "Found #{episodes.size} episodes in feed."

  sync = CookingIssues::Sync.new(episodes)
  sync.run
end

desc "List all episodes from the feed"
task episodes: HRN_FEED do
  feed = CookingIssues::Feed.new(HRN_FEED)
  feed.episodes.sort_by(&:number).each do |ep|
    status = Dir.glob(File.join("transcripts", "#{ep.slug}.*")).any? ? "✓" : " "
    puts "[#{status}] #{ep.number}. #{ep.title}"
  end
end
