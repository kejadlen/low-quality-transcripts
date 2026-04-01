require "nokogiri"

module CookingIssues
  Episode = Data.define(:number, :title, :published_at, :audio_url) do
    def slug
      formatted_number = format("%03d", number)
      safe_title = title
        .downcase
        .gsub(/[^a-z0-9\s-]/, "")
        .gsub(/\s+/, "-")
        .gsub(/-+/, "-")
        .sub(/-$/, "")
      "#{formatted_number}-#{safe_title}"
    end
  end

  module Feed
    def self.parse(path)
      doc = Nokogiri::XML(File.read(path))
      doc.xpath("//item").filter_map { |item| parse_item(item) }
    end

    def self.parse_item(item)
      number = item.at_xpath("itunes:episode")&.text&.to_i
      return nil unless number && number > 0

      Episode.new(
        number: number,
        title: item.at_xpath("title").text,
        published_at: item.at_xpath("pubDate").text,
        audio_url: item.at_xpath("enclosure")&.[]("url")
      )
    end

    private_class_method :parse_item
  end
end
