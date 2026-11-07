require "json"
require "pathname"
require "yaml"

require_relative "timestamp"

module CookingIssues
  # Merges per-episode entity extractions into cross-episode entities.
  class Graph
    Entity = Data.define(:name, :type, :slug, :mentions) do
      def episodes = mentions.keys
    end

    Related = Data.define(:entity, :shared)

    MIN_EPISODES = 2
    # The index shows at most this many topics by default; the rest sit behind
    # a toggle, and the cutoff rises with the corpus to keep it that way.
    FEATURED_TARGET = 60
    FEATURED_FLOOR = 3
    RELATED_LIMIT = 12

    # Turns name variants ("The Booker & Dax", "Crème Anglaise") into one key.
    def self.key(name)
      name.unicode_normalize(:nfkd)
        .gsub(/\p{Mn}/, "")
        .downcase
        .gsub("&", " and ")
        .gsub(/[^a-z0-9 ]/, " ")
        .squeeze(" ")
        .strip
        .delete_prefix("the ")
    end

    # extractions: { episode_slug => [mention hashes from bin/extract-entities] }
    def self.load(entity_paths, aliases_path)
      extractions = entity_paths.to_h { |path|
        [Pathname(path).basename(".json").to_s, JSON.parse(File.read(path)).fetch("mentions")]
      }
      aliases = aliases_path.exist? ? YAML.safe_load(aliases_path.read) || {} : {}
      new(extractions:, aliases:)
    end

    # Groups spelling variants that differ only in spacing ("Vita Prep", "Vitaprep").
    def self.match_key(name) = key(name).delete(" ")

    def initialize(extractions:, aliases:)
      ignored = aliases.fetch("ignore", []).to_set { self.class.match_key(it) }
      curated = aliases.fetch("entities", {})
      canonical_for = curated.each.with_object({}) do |(name, spec), map|
        [name, *spec.fetch("aliases", [])].each { map[self.class.match_key(it)] = name }
      end

      groups = Hash.new { |h, k| h[k] = [] }
      extractions.each do |episode, mentions|
        mentions.each do |m|
          raw = m.fetch("canonical")
          name = canonical_for.fetch(self.class.match_key(raw), raw)
          key = self.class.match_key(name)
          next if key.empty? || ignored.include?(key)

          groups[key] << { episode:, name:, type: m.fetch("type"), ts: m.fetch("ts") }
        end
      end

      names = groups.transform_values { |ms| tally_max(ms.map { it.fetch(:name) }) }
      types = groups.to_h { |key, ms|
        [key, curated.fetch(names.fetch(key), {}).fetch("type") { tally_max(ms.map { it.fetch(:type) }) }]
      }
      fold_plurals(groups, types)

      entities = groups.filter_map { |key, ms|
        name = names.fetch(key)
        type = types.fetch(key)
        # A lone first name ("John") collides across episodes, so it needs curating.
        next if type == "person" && !self.class.key(name).include?(" ") && !curated.key?(name)

        by_episode = ms.group_by { it.fetch(:episode) }
          .transform_values { |eps| eps.map { it.fetch(:ts) }.uniq.sort_by { Timestamp.seconds(it) } }
        next if by_episode.size < MIN_EPISODES

        Entity.new(name:, type:, slug: self.class.key(name).tr(" ", "-"), mentions: by_episode)
      }

      @entities = entities.sort_by { [-it.episodes.size, it.name.downcase] }
      @by_episode = Hash.new { |h, k| h[k] = [] }
      @entities.each do |e|
        e.episodes.each { @by_episode[it] << e }
      end
      @episode_count = extractions.size
      @featured_min = (FEATURED_FLOOR..).find { |n| @entities.count { it.episodes.size >= n } <= FEATURED_TARGET }
    end

    attr_reader :entities, :featured_min

    def for_episode(episode_slug) = @by_episode.fetch(episode_slug, [])

    # Weights shared episodes by rarity so ubiquitous entities (the host, the
    # station) don't top every list.
    def related(entity)
      scores = Hash.new(0.0)
      shared = Hash.new(0)
      entity.episodes.each do |ep|
        @by_episode.fetch(ep).each do |other|
          next if other.equal?(entity)

          scores[other] += Math.log(@episode_count.to_f / other.episodes.size)
          shared[other] += 1
        end
      end
      scores.max_by(RELATED_LIMIT) { |other, score| [score, other.name] }
        .map { |other, _| Related.new(entity: other, shared: shared.fetch(other)) }
    end

    private

    # Merges "Eggs" into "Egg" only when both exist with the same type, so
    # "Sears" (a place) stays apart from "Sear" (a technique).
    def fold_plurals(groups, types)
      groups.keys.each do |key|
        singular = [key.sub(/ies\z/, "y"), key.sub(/es\z/, ""), key.sub(/s\z/, "")]
          .find { it != key && groups.key?(it) && types.fetch(it) == types.fetch(key) }
        groups.fetch(singular).concat(groups.delete(key)) if singular
      end
    end

    # Most common value; ties go to the first one seen.
    def tally_max(values) = values.tally.max_by { |value, count| [count, -values.index(value)] }.first
  end
end
