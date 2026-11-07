module CookingIssues
  # Pulls the passage around a mention out of a rendered transcript.
  module Snippet
    Excerpt = Data.define(:before, :match, :after)

    # { "1:41" => "paragraph text", ... } from "[1:41] paragraph text" blocks.
    def self.paragraphs(text)
      text.split("\n\n").filter_map { |para|
        m = para.match(/\A\[([^\]]+)\]\s*(.*)/m)
        [m[1], m[2]] if m
      }.to_h
    end

    def self.excerpt(paragraph, surfaces, radius: 150)
      pattern = Regexp.union(surfaces.sort_by { -it.length }.map { /\b#{Regexp.escape(it)}\b/i })
      found = paragraph.match(pattern)
      return Excerpt.new(before: trim_end(paragraph, radius * 2), match: "", after: "") unless found

      Excerpt.new(
        before: trim_start(found.pre_match, radius),
        match: found[0],
        after: trim_end(found.post_match, radius),
      )
    end

    def self.trim_start(text, limit) = text.length > limit ? "…#{text[-limit..].sub(/\A\S*\s/, "")}" : text

    def self.trim_end(text, limit) = text.length > limit ? "#{text[0, limit].sub(/\s\S*\z/, "")}…" : text
  end
end
