require "cgi"
require "nokogiri"

module CookingIssues
  # House-ad paragraphs the feeds append to every summary.
  SUMMARY_BOILERPLATE = /\A(?:Have a question for Cooking Issues|Heritage Radio Network is a listener|Cooking Issues\s+is powered by|See Privacy Policy at|Keep Cooking Issues on the air|It's HRN's annual summer fund drive|In March, HRN began producing)/i

  Episode = Data.define(:title, :published_at, :audio_url, :summary) do
    def self.parse(item)
      new(
        title: item.at_xpath("title").text,
        published_at: item.at_xpath("pubDate").text,
        audio_url: item.at_xpath("enclosure")["url"],
        summary: parse_summary(item)
      )
    end

    # HRN summaries are plain text with blank-line paragraphs; Acast's are
    # HTML whose content ends at an <hr> ahead of the "Hosted on Acast"
    # footer. Turning tags into newlines covers both. Only the boilerplate
    # paragraphs go — real multi-paragraph notes (quotes, bullets, photo
    # captions) survive.
    def self.parse_summary(item)
      node = item.elements.find { it.name == "summary" } || item.at_xpath("description")
      return "" unless node

      (node.text.split(/<hr[^>]*>/i).first || "")
        .gsub(/<(?:p|br)\b[^>]*>/i, "\n\n")
        .gsub(/<[^>]+>/, "")
        .gsub("&nbsp;", " ")
        .then { CGI.unescapeHTML(it) }
        .split(/\n\s*\n/)
        .map { it.strip.gsub(/\s+/, " ") }
        .reject { it.empty? || SUMMARY_BOILERPLATE.match?(it) }
        .join("\n\n")
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
