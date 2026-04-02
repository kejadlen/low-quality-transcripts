require "nokogiri"

module CookingIssues
  Episode = Data.define(:title, :published_at, :audio_url) do
    def self.parse(item)
      new(
        title: item.at_xpath("title").text,
        published_at: item.at_xpath("pubDate").text,
        audio_url: item.at_xpath("enclosure")["url"]
      )
    end

    def slug
      title.downcase.gsub(/[^a-z0-9]+/, "-").chomp("-")
    end
  end

  module Feed
    def self.parse(path)
      doc = Nokogiri::XML(File.read(path))
      doc.xpath("//item")
        .map { Episode.parse(it) }
        .reverse
    end
  end
end
