require "json"
require "net/http"
require "pathname"
require "uri"

require_relative "lib/config"
require_relative "lib/episode_task"
require_relative "lib/feed"
require_relative "lib/download"

require_relative "lib/transcribers"

CONFIG = CookingIssues::Config.from_env(Transcribers)
CONFIG.transcriber.register

# --- Feed downloads ---

[
  CONFIG.cache_dir,
  CONFIG.audio_dir,
  CONFIG.transcriber_cache_dir,
  CONFIG.text_dir,
].each do |dir|
  directory dir.to_s
end

file CONFIG.hrn_feed_path.to_s => CONFIG.cache_dir.to_s do
  puts "Downloading HRN feed..."
  uri = URI(CONFIG.hrn_feed_url)
  response = Net::HTTP.get_response(uri)
  raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  CONFIG.hrn_feed_path.write(response.body)
end

task :fetch_acast_feed => CONFIG.cache_dir.to_s do
  uri = URI(CONFIG.acast_feed_url)
  request = Net::HTTP::Get.new(uri)
  request["If-None-Match"] = CONFIG.acast_etag_path.read.strip if CONFIG.acast_etag_path.exist?

  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(request) do |response|
      case response
      when Net::HTTPNotModified
        puts "Acast feed unchanged."
      when Net::HTTPSuccess
        File.open(CONFIG.acast_feed_path.to_s, "wb") do |f|
          response.read_body { |chunk| f.write(chunk) }
        end
        CONFIG.acast_etag_path.write(response["etag"]) if response["etag"]
        puts "Acast feed updated."
      else
        raise "Acast feed returned #{response.code}"
      end
    end
  end
end

Rake::Task[CONFIG.hrn_feed_path.to_s].invoke
Rake::Task[:fetch_acast_feed].invoke

episodes = CookingIssues::Feed.parse(CONFIG.hrn_feed_path) +
           CookingIssues::Feed.parse(CONFIG.acast_feed_path)

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

desc "Generate HTML transcript pages"
task :pages do
  require "cgi"
  require "erb"

  templates_dir = File.expand_path("lib/pages", __dir__)
  index_template = ERB.new(File.read("#{templates_dir}/index.html.erb"))
  episode_template = ERB.new(File.read("#{templates_dir}/episode.html.erb"))

  transcripts = EPISODE_TASKS
    .select { |et| Pathname(et.text_path).exist? }
    .map do |et|
      {
        number: et.number,
        title: et.episode.title.sub(/^Episode #{et.number}:\s+/, ""),
        slug: et.slug,
        audio_url: et.episode.audio_url,
        text: File.read(et.text_path)
      }
    end

  CONFIG.pages_dir.mkpath

  transcripts.each do |ep|
    html = episode_template.result_with_hash(ep:)
    (CONFIG.pages_dir / "#{ep[:slug]}.html").write(html)
  end

  html = index_template.result_with_hash(transcripts:)
  (CONFIG.pages_dir / "index.html").write(html)

  puts "Generated #{transcripts.length} episode pages + index."

  sh "uv", "run", "--with", "pagefind[bin]", "python3", "-m", "pagefind", "--site", CONFIG.pages_dir.to_s

  # TODO: Uncomment when DNS is ready for custom domain.
  # (CONFIG.pages_dir / "CNAME").write("low-quality-transcripts.kejadlen.dev")
end

desc "Serve the generated pages locally"
task serve: :pages do
  require "puma"
  require "puma/configuration"
  require "puma/launcher"
  require "rack"

  files = Rack::Files.new(CONFIG.pages_dir.to_s)
  app = ->(env) do
    env["PATH_INFO"] = "/index.html" if env["PATH_INFO"] == "/"
    files.call(env)
  end
  config = Puma::Configuration.new do |c|
    c.port 8000
    c.app app
    c.log_requests
  end

  puts "Serving #{CONFIG.pages_dir} at http://localhost:8000"
  Puma::Launcher.new(config).run
end
