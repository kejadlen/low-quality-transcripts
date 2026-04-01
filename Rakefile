require_relative "lib/feed"
require_relative "lib/sync"

task default: :sync

desc "Fetch the feed, download episodes missing transcripts"
task :sync do
  feed = CookingIssues::Feed.new
  episodes = feed.episodes
  puts "Found #{episodes.size} episodes in feed."

  sync = CookingIssues::Sync.new(episodes)
  sync.run
end

desc "List all episodes from the feed"
task :episodes do
  feed = CookingIssues::Feed.new
  feed.episodes.sort_by(&:number).each do |ep|
    status = Dir.glob(File.join("transcripts", "#{ep.slug}.*")).any? ? "✓" : " "
    puts "[#{status}] #{ep.number}. #{ep.title}"
  end
end
