require "minitest/autorun"

require "snippet"

class SnippetTest < Minitest::Test
  def test_paragraphs_key_text_by_timestamp
    text = "[0:10] Hello there.\n\n[1:00:24] Second one."

    assert_equal({ "0:10" => "Hello there.", "1:00:24" => "Second one." }, CookingIssues::Snippet.paragraphs(text))
  end

  def test_excerpt_marks_the_longest_matching_surface
    e = CookingIssues::Snippet.excerpt("We used the rotary evaporator today.", ["rotary", "Rotary Evaporator"])

    assert_equal ["We used the ", "rotary evaporator", " today."], [e.before, e.match, e.after]
  end

  def test_excerpt_trims_at_word_boundaries
    para = "#{"word " * 50}salt#{" word" * 50}"
    e = CookingIssues::Snippet.excerpt(para, ["salt"], radius: 20)

    assert_equal ["…word word word ", "salt", " word word word…"], [e.before, e.match, e.after]
  end

  def test_excerpt_without_a_match_shows_the_start_of_the_paragraph
    e = CookingIssues::Snippet.excerpt("Nothing here.", ["salt"])

    assert_equal ["Nothing here.", ""], [e.before, e.match]
  end
end
