require "cgi"
require "erb"

SITE_DIR = Pathname("site")

desc "Generate an HTML page of transcripts"
task :site do
  transcripts = EPISODE_TASKS
    .select { |et| Pathname(et.text_path).exist? }
    .map do |et|
      {
        number: et.number,
        title: et.episode.title,
        slug: et.slug,
        text: File.read(et.text_path)
      }
    end

  template = File.read(File.expand_path("../../site.html.erb", __FILE__))
  html = ERB.new(template).result(binding)

  SITE_DIR.mkpath
  (SITE_DIR / "index.html").write(html)
  puts "Generated site/index.html with #{transcripts.length} episodes."
end
