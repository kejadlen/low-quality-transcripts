require "nokogiri"

module CookingIssues
  Episode = Data.define(:number, :title, :published_at, :audio_url) do
    def self.parse(item)
      new(
        number: item.at_xpath("itunes:episode").text.to_i,
        title: item.at_xpath("title").text,
        published_at: item.at_xpath("pubDate").text,
        audio_url: item.at_xpath("enclosure")["url"]
      )
    end

    def slug
      safe_title = title.downcase.gsub(/[^a-z0-9]+/, "-").chomp("-")
      format("%03d-%s", number, safe_title)
    end

    def audio_path
      "audio/#{slug}.mp3"
    end

    def transcript_path
      audio_path.pathmap("%{^audio/,transcripts/}X.json")
    end
  end

  module Feed
    def self.parse(path)
      doc = Nokogiri::XML(File.read(path))
      doc.xpath("//item")
        .map { Episode.parse(it) }
        .sort_by(&:number)
        .to_h { [it.number, it] }
    end
  end
end
