require "minitest/autorun"

require "timestamp"

class TimestampTest < Minitest::Test
  def test_anchor_matches_episode_page_ids
    assert_equal "t-1-41", CookingIssues::Timestamp.anchor("1:41")
    assert_equal "t-1-00-24", CookingIssues::Timestamp.anchor("1:00:24")
  end

  def test_seconds
    assert_equal 101, CookingIssues::Timestamp.seconds("1:41")
    assert_equal 3624, CookingIssues::Timestamp.seconds("1:00:24")
  end
end
