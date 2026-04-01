# frozen_string_literal: true

require "fileutils"
require "net/http"
require "uri"

module CookingIssues
  # Downloads episodes that don't yet have transcripts.
  class Sync
    AUDIO_DIR = File.expand_path("../audio", __dir__)
    TRANSCRIPTS_DIR = File.expand_path("../transcripts", __dir__)

    def initialize(episodes)
      @episodes = episodes
    end

    def run
      FileUtils.mkdir_p(AUDIO_DIR)
      missing = untranscribed_episodes
      if missing.empty?
        puts "All episodes have transcripts."
        return
      end

      puts "#{missing.size} episodes need transcripts."
      missing.each do |episode|
        download(episode)
      end
    end

    private

    def untranscribed_episodes
      @episodes.reject { |ep| transcript_exists?(ep) }.sort_by(&:number)
    end

    def transcript_exists?(episode)
      Dir.glob(File.join(TRANSCRIPTS_DIR, "#{episode.slug}.*")).any?
    end

    def download(episode)
      dest = File.join(AUDIO_DIR, "#{episode.slug}.mp3")
      if File.exist?(dest)
        puts "  already downloaded: #{episode.slug}"
        return
      end

      puts "  downloading: #{episode.slug}"
      uri = URI(episode.audio_url)
      download_with_redirects(uri, dest)
    end

    def download_with_redirects(uri, dest, limit = 5)
      raise "Too many redirects" if limit == 0

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          case response
          when Net::HTTPRedirection
            download_with_redirects(URI(response["location"]), dest, limit - 1)
          when Net::HTTPSuccess
            File.open(dest, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          else
            raise "Download failed for #{uri}: #{response.code}"
          end
        end
      end
    end
  end
end
