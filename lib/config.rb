require "pathname"

module CookingIssues
  Config = Data.define(
    :cache_dir,
    :audio_dir,
    :transcripts_dir,
    :hrn_feed_path,
    :hrn_feed_url,
    :patreon_feed_path,
    :patreon_feed_url,
    :transcriber,
    :transcriber_cache_dir,
    :text_dir
  ) do
    def self.from_env(transcribers)
      cache_dir = Pathname("cache")
      transcriber = transcribers.resolve(ENV.fetch("TRANSCRIBER", "sous_chef"))

      new(
        cache_dir: cache_dir,
        audio_dir: cache_dir / "audio",
        transcripts_dir: Pathname("transcripts"),
        hrn_feed_path: cache_dir / "hrn_feed.xml",
        hrn_feed_url: "https://rss.art19.com/cooking-issues",
        patreon_feed_path: cache_dir / "patreon_feed.xml",
        patreon_feed_url: ENV.fetch("PATREON_FEED_URL"),
        transcriber: transcriber,
        transcriber_cache_dir: cache_dir / transcriber.name,
        text_dir: Pathname("transcripts") / transcriber.name
      )
    end
  end
end
