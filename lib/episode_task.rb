module CookingIssues
  EpisodeTask = Data.define(:index, :episode, :config) do
    def number = index + 1
    def slug = format("%03d-%s", number, episode.slug)
    def audio_path = (config.audio_dir / "#{slug}.mp3").to_s
    def transcript_path = (config.transcriber_cache_dir / "#{slug}.json").to_s
    def text_path = (config.text_dir / "#{slug}.txt").to_s
  end
end
