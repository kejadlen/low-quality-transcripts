require "cgi"
require "erb"
require "json"
require "net/http"
require "pathname"
require "time"
require "uri"

require_relative "lib/config"
require_relative "lib/episode_task"
require_relative "lib/feed"
require_relative "lib/download"

transcriber_key = ENV.fetch("TRANSCRIBER", "parakeet")
CONFIG = CookingIssues::Config.from_env(transcriber_key:)
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

BASE_URL = "https://issues.cooking"
RAKEFILE_PATH = File.expand_path(__FILE__)

def page_source(name) = File.expand_path("lib/pages/#{name}", __dir__)

LAYOUT_TEMPLATE_PATH = page_source("layout.html.erb")
EPISODE_TEMPLATE_PATH = page_source("episode.html.erb")
INDEX_TEMPLATE_PATH = page_source("index.html.erb")

# Titles, canonicals, and the player are rendered here, so this file is a page source too.
EPISODE_PAGE_SOURCES = [
  RAKEFILE_PATH,
  LAYOUT_TEMPLATE_PATH,
  EPISODE_TEMPLATE_PATH,
  page_source("episode.css"),
  page_source("episode.js"),
]
INDEX_PAGE_SOURCES = [
  RAKEFILE_PATH,
  LAYOUT_TEMPLATE_PATH,
  INDEX_TEMPLATE_PATH,
  page_source("index.css"),
  page_source("index.js"),
]

# Renders an inner template inside the shared layout.
# page_vars are passed to the inner template; layout_vars supply
# title, styles, head, scripts, and post_footer to the layout.
def render_page(inner_path, page_vars:, layout_vars:)
  inner = ERB.new(File.read(inner_path))
  content = inner.result_with_hash(**page_vars)

  layout = ERB.new(File.read(LAYOUT_TEMPLATE_PATH))
  defaults = { head: "", styles: "", scripts: "", post_footer: "" }
  layout.result_with_hash(**defaults, **layout_vars, content:)
end

# Inlined rather than linked so the assets stay out of Ruby heredocs, where
# a stray #{} would interpolate.
def inline_script(name, type: nil)
  %(<script#{%( type="#{type}") if type}>\n#{File.read(page_source(name))}</script>\n)
end

# --- Per-episode file tasks ---

EPISODE_TASKS.each do |et|
  # Text files are committed but audio and transcripts are not.
  # Skip the download/transcribe/render chain in CI so the HTML
  # task doesn't try to rebuild the entire pipeline.
  unless ENV["CI"]
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

  file et.html_path => [et.text_path, CONFIG.pages_dir.to_s, *EPISODE_PAGE_SOURCES] do
    ep = {
      number: et.number,
      title: et.episode.title.sub(/^Episode #{et.number}:\s+/, ""),
      slug: et.slug,
      audio_url: et.episode.audio_url,
      text: File.read(et.text_path)
    }

    html = render_page(EPISODE_TEMPLATE_PATH,
      page_vars: { ep: },
      layout_vars: {
        title: "#{CGI.escapeHTML("#{ep.fetch(:number)}. #{ep.fetch(:title)}")} — Cooking Issues",
        # Self-referential so pagefind-highlight's ?highlight= URLs don't read
        # as duplicates.
        head: %(<link rel="canonical" href="#{BASE_URL}/#{et.slug}.html" />\n),
        styles: File.read(page_source("episode.css")),
        post_footer: <<~HTML,
          <div class="player">
            <p class="player-note">Timestamps may be off due to dynamic ad insertion.</p>
            <audio id="audio" controls preload="none" src="#{CGI.escapeHTML(ep.fetch(:audio_url))}"></audio>
          </div>
        HTML
        scripts: inline_script("episode.js", type: "module"),
      })

    File.write(et.html_path, html)
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

directory CONFIG.pages_dir.to_s

EPISODE_HTML_TASKS = EPISODE_TASKS.select { |et| Pathname(et.text_path).exist? }
EPISODE_HTML_PATHS = EPISODE_HTML_TASKS.map(&:html_path)
INDEX_HTML_PATH = (CONFIG.pages_dir / "index.html").to_s

file INDEX_HTML_PATH => [*EPISODE_HTML_PATHS, *INDEX_PAGE_SOURCES] do
  transcripts = EPISODE_HTML_TASKS.map { |et|
    {
      number: et.number,
      title: et.episode.title.sub(/^Episode #{et.number}:\s+/, ""),
      slug: et.slug,
    }
  }

  html = render_page(INDEX_TEMPLATE_PATH,
    page_vars: { transcripts: },
    layout_vars: {
      title: "Cooking Issues Transcripts",
      head: <<~HEAD,
        <link href="./pagefind/pagefind-component-ui.css" rel="stylesheet">
        <link rel="canonical" href="#{BASE_URL}/" />
      HEAD
      styles: File.read(page_source("index.css")),
      scripts: %(<script src="./pagefind/pagefind-component-ui.js"></script>\n) + inline_script("index.js"),
    })

  File.write(INDEX_HTML_PATH, html)

  puts "Generated #{transcripts.length} episode pages + index."
end

# TODO: Uncomment when DNS is ready for custom domain.
# CNAME_PATH = (CONFIG.pages_dir / "CNAME").to_s
# file CNAME_PATH => CONFIG.pages_dir.to_s do
#   File.write(CNAME_PATH, "low-quality-transcripts.kejadlen.dev")
# end

ALL_HTML_PATHS = EPISODE_HTML_PATHS + [INDEX_HTML_PATH]

SITEMAP_PATH = (CONFIG.pages_dir / "sitemap.xml").to_s
ROBOTS_PATH = (CONFIG.pages_dir / "robots.txt").to_s

# pubDate is RFC 822; sitemaps want W3C datetime. A malformed date costs one
# lastmod hint, so drop it rather than fail the build.
def sitemap_lastmod(pub_date)
  Time.rfc2822(pub_date).utc.xmlschema
rescue ArgumentError
  nil
end

file SITEMAP_PATH => [*ALL_HTML_PATHS, RAKEFILE_PATH, CONFIG.pages_dir.to_s] do
  entries = EPISODE_HTML_TASKS.map { |et|
    { loc: "#{BASE_URL}/#{et.slug}.html", lastmod: sitemap_lastmod(et.episode.published_at) }
  }
  entries.unshift({ loc: "#{BASE_URL}/", lastmod: entries.filter_map { it.fetch(:lastmod) }.max })

  urls = entries.map { |entry|
    lastmod = entry.fetch(:lastmod)
    <<~XML.chomp
      <url>
      <loc>#{entry.fetch(:loc)}</loc>
      #{"<lastmod>#{lastmod}</lastmod>" if lastmod}
      </url>
    XML
  }

  File.write(SITEMAP_PATH, <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls.join("\n")}
    </urlset>
  XML

  puts "Generated sitemap with #{entries.length} URLs."
end

file ROBOTS_PATH => [RAKEFILE_PATH, CONFIG.pages_dir.to_s] do
  File.write(ROBOTS_PATH, <<~TXT)
    User-agent: *
    Allow: /

    Sitemap: #{BASE_URL}/sitemap.xml
  TXT
end

PAGEFIND_VERSION = "1.5.2"
PAGEFIND_STAMP = (CONFIG.pages_dir / ".pagefind-stamp").to_s

file PAGEFIND_STAMP => ALL_HTML_PATHS do
  sh "uv", "run", "--with", "pagefind[bin]==#{PAGEFIND_VERSION}", "python3", "-m", "pagefind", "--site", CONFIG.pages_dir.to_s
  FileUtils.touch(PAGEFIND_STAMP)
end

desc "Generate HTML transcript pages and search index"
task html: [*ALL_HTML_PATHS, SITEMAP_PATH, ROBOTS_PATH, PAGEFIND_STAMP]

desc "Serve the generated pages locally"
task serve: :html do
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
