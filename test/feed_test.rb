require "minitest/autorun"

require "nokogiri"

require "feed"

class FeedTest < Minitest::Test
  ITEM_XML = <<~XML.chomp
    <title>Bagels</title>
    <pubDate>Sat, 14 Nov 2026 08:00:00 GMT</pubDate>
    <enclosure url="https://example.com/audio.mp3"/>
  XML

  def parse_episode(inner_xml)
    doc = Nokogiri::XML("<item xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\">#{ITEM_XML}#{inner_xml}</item>")
    CookingIssues::Episode.parse(doc.root)
  end

  def test_summary_strips_hrn_boilerplate_paragraphs
    ep = parse_episode(<<~XML)

      <itunes:summary>Real summary of the show.

      Have a question for Cooking Issues? Send us a voicememo or ask in the chatroom.

      Heritage Radio Network is a listener supported nonprofit podcast network. Support Cooking Issues by becoming a member!

      Cooking Issues is powered by Simplecast.

      See Privacy Policy at https://art19.com/privacy.
      </itunes:summary>
    XML

    assert_equal "Real summary of the show.", ep.summary
  end

  def test_summary_strips_html_and_the_acast_footer
    ep = parse_episode(<<~XML)
      <itunes:summary><![CDATA[A listener asks if <i>guacamole</i> is a salad.<hr><p>Hosted on Acast. See <a href="https://acast.com/privacy">acast.com/privacy</a> for more information.</p>]]></itunes:summary>
    XML

    assert_equal "A listener asks if guacamole is a salad.", ep.summary
  end

  def test_summary_keeps_real_paragraphs_and_unescapes_entities
    ep = parse_episode(<<~XML)
      <itunes:summary><![CDATA[<p>First paragraph, on milk &amp; fat-washing.</p><br><p>“A quote worth keeping.”</p><p>&nbsp;</p>]]></itunes:summary>
    XML

    assert_equal "First paragraph, on milk & fat-washing.\n\n“A quote worth keeping.”", ep.summary
  end

  def test_summary_falls_back_to_description
    ep = parse_episode(<<~XML)
      <description><![CDATA[<p>From the description element.</p>]]></description>
    XML

    assert_equal "From the description element.", ep.summary
  end

  def test_summary_is_empty_without_a_summary_or_description
    assert_equal "", parse_episode("").summary
  end
end
