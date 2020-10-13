require 'mechanize/test_case'

class TestMechanizeXmlFile < Mechanize::TestCase

  def setup
    super

    uri = URI 'http://example.com/foo.xml'
    @xml = Mechanize::XmlFile.new uri, nil, <<-XML
      <languages>
        <language>Ruby</language>
        <language>Perl</language>
      </languages>
    XML
  end

  def test_xml
    assert_kind_of Nokogiri::XML::Document, @xml.xml
  end

  def test_search
    assert_equal ['Ruby', 'Perl'], @xml.search('language').map { |n| n.text }
  end

  def test_at
    assert_equal 'Perl', @xml.at('//language[2]').text
  end

end