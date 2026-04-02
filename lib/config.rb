require "pathname"

require_relative "transcribers"

module CookingIssues
  Config = Data.define(
    :cache_dir,
    :audio_dir,
    :transcripts_dir,
    :pages_dir,
    :hrn_feed_path,
    :hrn_feed_url,
    :acast_feed_path,
    :acast_feed_url,
    :acast_etag_path,
    :transcriber,
    :transcriber_cache_dir,
    :text_dir
  ) do
    def self.from_env(transcriber_key:)
      cache_dir = Pathname("cache")
      transcriber = Transcribers.resolve(transcriber_key, cache_dir: cache_dir)

      new(
        cache_dir: cache_dir,
        audio_dir: cache_dir / "audio",
        transcripts_dir: Pathname("transcripts"),
        pages_dir: Pathname("pages"),
        hrn_feed_path: cache_dir / "hrn_feed.xml",
        hrn_feed_url: "https://rss.art19.com/cooking-issues",
        acast_feed_path: cache_dir / "acast_feed.xml",
        acast_feed_url: "https://feeds.acast.com/public/shows/cooking-issues-with-dave-arnold",
        acast_etag_path: cache_dir / "acast_feed.etag",
        transcriber: transcriber,
        transcriber_cache_dir: cache_dir / transcriber.name,
        text_dir: Pathname("transcripts") / transcriber.name
      )
    end
  end
end
