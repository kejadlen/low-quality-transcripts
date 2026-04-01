# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "uri"

module CookingIssues
  # Parses a podcast RSS feed and returns episode data.
  class Feed
    FEED_URL = "https://rss.art19.com/cooking-issues"

    Episode = Struct.new(:number, :title, :published_at, :audio_url, keyword_init: true) do
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

    def initialize(url = FEED_URL)
      @url = url
    end

    def episodes
      @episodes ||= parse(fetch)
    end

    private

    def fetch
      uri = URI(@url)
      response = Net::HTTP.get_response(uri)
      raise "Feed returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def parse(xml)
      doc = Nokogiri::XML(xml)
      doc.xpath("//item").filter_map { |item| parse_item(item) }
    end

    def parse_item(item)
      number = item.at_xpath("itunes:episode")&.text&.to_i
      return nil unless number && number > 0

      Episode.new(
        number: number,
        title: item.at_xpath("title").text,
        published_at: item.at_xpath("pubDate").text,
        audio_url: item.at_xpath("enclosure")&.[]("url")
      )
    end
  end
end
