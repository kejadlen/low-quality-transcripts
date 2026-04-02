require "cgi"
require "erb"

SITE_DIR = Pathname("site")

desc "Generate an HTML page of transcripts"
task :site do
  transcripts = []
  EPISODES.each_with_index do |ep, i|
    txt = Pathname(text_path(i, ep))
    next unless txt.exist?

    transcripts << {
      number: i + 1,
      title: ep.title,
      slug: episode_slug(i, ep),
      text: txt.read
    }
  end

  template = File.read(File.expand_path("../../site.html.erb", __FILE__))
  html = ERB.new(template).result(binding)

  SITE_DIR.mkpath
  (SITE_DIR / "index.html").write(html)
  puts "Generated site/index.html with #{transcripts.length} episodes."
end
