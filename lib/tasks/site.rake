require "cgi"
require "erb"

SITE_DIR = Pathname("site")

desc "Generate an HTML page of transcripts"
task :site do
  episodes = EPISODES.values.sort_by(&:number).select { |ep| Pathname(text_path(ep)).exist? }

  transcripts = episodes.map do |ep|
    {
      number: ep.number,
      title: ep.title,
      slug: ep.slug,
      text: File.read(text_path(ep))
    }
  end

  template = File.read(File.expand_path("lib/site.html.erb", __dir__))
  html = ERB.new(template).result(binding)

  SITE_DIR.mkpath
  (SITE_DIR / "index.html").write(html)
  puts "Generated site/index.html with #{transcripts.length} episodes."
end
