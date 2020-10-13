require 'mechanize/test_case'

class TestMechanizePluggableParser < Mechanize::TestCase

  def setup
    super

    @pp = @mech.pluggable_parser
  end

  def test_aref
    @pp['text/html'] = Mechanize::Download

    assert_equal Mechanize::Download, @pp['text/html']
  end

  def test_csv
    @pp.csv = Mechanize::Download

    assert_equal Mechanize::Download, @pp['text/csv']
  end

  def test_html
    assert_equal Mechanize::Page, @pp['text/html']

    @pp.html = Mechanize::Download

    assert_equal Mechanize::Download, @pp['text/html']
  end

  def test_parser
    assert_equal Mechanize::XmlFile, @pp.parser('text/xml')
    assert_equal Mechanize::File, @pp.parser(nil)
  end

  def test_parser_mime
    @pp['image/png'] = :png

    assert_equal :png, @pp.parser('x-image/x-png')
    assert_equal :png, @pp.parser('image/png')
    assert_equal Mechanize::Image, @pp.parser('image')
  end

  def test_parser_bogus
    assert_nil @pp['bogus']

    assert_equal Mechanize::File, @pp.parser('bogus')
  end

  def test_pdf
    @pp.pdf = Mechanize::Download

    assert_equal Mechanize::Download, @pp['application/pdf']
  end

  def test_xml
    assert_equal Mechanize::XmlFile, @pp['text/xml']
    assert_equal Mechanize::XmlFile, @pp['application/xml']

    @pp.xml = Mechanize::Download

    assert_equal Mechanize::Download, @pp['text/xml']
    assert_equal Mechanize::Download, @pp['application/xml']
  end

end

