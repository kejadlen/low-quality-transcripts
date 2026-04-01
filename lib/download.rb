require "net/http"
require "uri"

module CookingIssues
  module Download
    def self.fetch(url, dest, limit = 5)
      raise "Too many redirects" if limit == 0

      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          case response
          when Net::HTTPRedirection
            fetch(response["location"], dest, limit - 1)
          when Net::HTTPSuccess
            File.open(dest, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          else
            raise "Download failed for #{url}: #{response.code}"
          end
        end
      end
    end
  end
end
