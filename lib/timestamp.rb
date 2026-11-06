module CookingIssues
  # Transcript paragraph labels like "1:41" or "1:00:24".
  module Timestamp
    def self.clean(label) = label.gsub(/[^0-9:]/, "")

    def self.anchor(label) = "t-#{clean(label).tr(":", "-")}"

    def self.seconds(label) = clean(label).split(":").map(&:to_i).reduce(0) { |acc, n| acc * 60 + n }
  end
end
