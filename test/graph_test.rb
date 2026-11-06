require "minitest/autorun"

require "graph"

class GraphTest < Minitest::Test
  def mention(canonical, type: "person", ts: "1:00") = { "canonical" => canonical, "type" => type, "surface" => canonical, "ts" => ts }

  def build(extractions, aliases = {}) = CookingIssues::Graph.new(extractions:, aliases:)

  def test_key_folds_case_accents_ampersands_and_leading_article
    assert_equal "booker and dax", CookingIssues::Graph.key("The Booker & Dax")
    assert_equal "creme anglaise", CookingIssues::Graph.key("Crème Anglaise")
  end

  def test_requires_two_episodes
    graph = build({ "a" => [mention("Harold McGee")], "b" => [mention("Chris Young")] })

    assert_empty graph.entities
  end

  def test_aliases_merge_variants_into_the_canonical_name
    aliases = { "entities" => { "Harold McGee" => { "type" => "person", "aliases" => ["harold"] } } }
    graph = build({ "a" => [mention("Harold")], "b" => [mention("harold mcgee")] }, aliases)

    assert_equal [["Harold McGee", %w[a b]]], graph.entities.map { [it.name, it.episodes.sort] }
  end

  def test_drops_uncurated_single_word_people
    graph = build({ "a" => [mention("John")], "b" => [mention("John")] })

    assert_empty graph.entities
  end

  def test_ignore_list_drops_names
    graph = build({ "a" => [mention("um")], "b" => [mention("Um")] }, { "ignore" => ["um"] })

    assert_empty graph.entities
  end

  def test_type_is_the_majority_across_mentions
    graph = build({
      "a" => [mention("Liquid nitrogen", type: "equipment")],
      "b" => [mention("liquid nitrogen", type: "ingredient")],
      "c" => [mention("Liquid Nitrogen", type: "ingredient")],
    })

    assert_equal ["ingredient"], graph.entities.map(&:type)
  end

  def test_timestamps_sort_by_time_not_text
    graph = build({ "a" => [mention("Chris Young", ts: "1:00:24"), mention("Chris Young", ts: "9:05")], "b" => [mention("Chris Young")] })

    assert_equal ["9:05", "1:00:24"], graph.entities.first.mentions.fetch("a")
  end

  def test_related_favors_rare_entities_over_ubiquitous_ones
    everywhere = %w[a b c d].to_h { [it, [mention("Dave Arnold")]] }
    extractions = everywhere.merge(
      "a" => [mention("Dave Arnold"), mention("Harold McGee"), mention("Rotary evaporator", type: "equipment")],
      "b" => [mention("Dave Arnold"), mention("Harold McGee"), mention("Rotary evaporator", type: "equipment")],
    )
    graph = build(extractions)
    mcgee = graph.entities.find { it.name == "Harold McGee" }

    assert_equal "Rotary evaporator", graph.related(mcgee).first.entity.name
  end
end
