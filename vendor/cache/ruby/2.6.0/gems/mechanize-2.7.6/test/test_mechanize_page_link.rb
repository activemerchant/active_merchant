# coding: utf-8

require 'mechanize/test_case'

class TestMechanizePageLink < Mechanize::TestCase

  WINDOWS_1255 = <<-HTML
<meta http-equiv="content-type" content="text/html; charset=windows-1255">
<title>hi</title>
  HTML

  BAD = <<-HTML
<meta http-equiv="content-type" content="text/html; charset=windows-1255">
<title>Bia\xB3ystok</title>
  HTML
  BAD.force_encoding Encoding::BINARY if defined? Encoding

  SJIS_TITLE = "\x83\x65\x83\x58\x83\x67"

  SJIS_AFTER_TITLE = <<-HTML
<title>#{SJIS_TITLE}</title>
<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
  HTML

  SJIS_AFTER_TITLE.force_encoding Encoding::BINARY if defined? Encoding

  SJIS_BAD_AFTER_TITLE = <<-HTML
<title>#{SJIS_TITLE}</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  HTML

  SJIS_BAD_AFTER_TITLE.force_encoding Encoding::BINARY if defined? Encoding

  UTF8_TITLE = 'テスト'
  UTF8 = <<-HTML
<title>#{UTF8_TITLE}</title>
<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">
  HTML

  ENCODING_ERROR_CLASS = Nokogiri::XML::SyntaxError

  def setup
    super

    @uri = URI('http://example')
    @res = { 'content-type' => 'text/html' }
    @body = '<title>hi</title>'
  end

  def util_page body = @body, res = @res
    Mechanize::Page.new @uri, res, body && body.force_encoding(Encoding::BINARY), 200, @mech
  end

  def nkf_dependency?
    if RUBY_ENGINE == 'ruby'
      false
    else
      meth = caller[0][/`(\w+)/, 1]
      warn "#{meth}: skipped because this feature currently depends on NKF"
      true
    end
  end

  def test_override_content_type
    page = Mechanize::Page.new nil, {'content-type' => 'text/html'}, WINDOWS_1255
    assert page
    assert_equal 'text/html; charset=windows-1255', page.content_type
  end

  def test_canonical_uri
    page = @mech.get("http://localhost/canonical_uri.html")
    assert_equal(URI("http://localhost/canonical_uri"), page.canonical_uri)

    page = @mech.get("http://localhost/file_upload.html")
    assert_nil page.canonical_uri
  end

  def test_canonical_uri_unescaped
    page = util_page <<-BODY
<head>
  <link rel="canonical" href="http://example/white space"/>
</head>
    BODY

    assert_equal @uri + '/white%20space', page.canonical_uri
  end

  def test_charset_from_content_type
    charset = Mechanize::Page.__send__ :charset_from_content_type, 'text/html;charset=UTF-8'

    assert_equal 'UTF-8', charset
  end

  def test_charset_from_bad_content_type
    charset = Mechanize::Page.__send__ :charset_from_content_type, 'text/html'

    assert_nil charset
  end

  def test_encoding
    page = util_page WINDOWS_1255

    assert_equal 'windows-1255', page.encoding
  end

  def test_encoding_charset_after_title
    page = util_page SJIS_AFTER_TITLE

    assert_equal false, page.encoding_error?

    assert_equal 'Shift_JIS', page.encoding
  end

  def test_encoding_charset_after_title_bad
    return if nkf_dependency?

    page = util_page UTF8

    assert_equal false, page.encoding_error?

    assert_equal 'UTF-8', page.encoding
  end

  def test_encoding_charset_after_title_double_bad
    return if nkf_dependency?

    page = util_page SJIS_BAD_AFTER_TITLE

    assert_equal false, page.encoding_error?

    assert_equal 'SHIFT_JIS', page.encoding
  end

  def test_encoding_charset_bad
    return if nkf_dependency?

    page = util_page "<title>#{UTF8_TITLE}</title>"
    page.encodings.replace %w[
      UTF-8
      Shift_JIS
    ]

    assert_equal false, page.encoding_error?

    assert_equal 'UTF-8', page.encoding
  end

  def test_encoding_meta_charset
    page = util_page "<meta charset='UTF-8'>"

    assert_equal 'UTF-8', page.encoding
  end

  def test_encoding_equals
    page = util_page
    page.meta_refresh
    assert page.instance_variable_get(:@meta_refresh)

    page.encoding = 'UTF-8'

    assert_nil page.instance_variable_get(:@meta_refresh)

    assert_equal 'UTF-8', page.encoding
    assert_equal 'UTF-8', page.parser.encoding
  end

  def test_page_encoding_error?
    page = util_page
    page.parser.errors.clear
    assert_equal false, page.encoding_error?
  end

  def test_detect_libxml2error_indicate_encoding
    page = util_page
    page.parser.errors.clear

    # error in libxml2-2.7.8/parser.c, HTMLparser.c or parserInternals.c
    page.parser.errors = [ENCODING_ERROR_CLASS.new("Input is not proper UTF-8, indicate encoding !\n")]
    assert_equal true, page.encoding_error?
  end

  def test_detect_libxml2error_invalid_char
    page = util_page
    page.parser.errors.clear

    # error in libxml2-2.7.8/HTMLparser.c
    page.parser.errors = [ENCODING_ERROR_CLASS.new("Invalid char in CDATA 0x%X\n")]
    assert_equal true, page.encoding_error?
  end

  def test_detect_libxml2error_input_conversion_failed
    page = util_page
    page.parser.errors.clear

    # error in libxml2-2.7.8/encoding.c
    page.parser.errors = [ENCODING_ERROR_CLASS.new("input conversion failed due to input error\n")]
    assert_equal true, page.encoding_error?
  end

  def test_detect_libxml2error_which_unsupported_by_mechanize
    page = util_page
    page.parser.errors.clear

    # error in libxml2-2.7.8/HTMLparser.c
    page.parser.errors = [ENCODING_ERROR_CLASS.new("encoder error\n")]
    assert_equal false, page.encoding_error?
  end

  def test_encoding_equals_before_parser
    # document has a bad encoding information - windows-1255
    page = util_page BAD

    # encoding is wrong, so user wants to force ISO-8859-2
    page.encoding = 'ISO-8859-2'

    assert_equal false, page.encoding_error?
    assert_equal 'ISO-8859-2', page.encoding
    assert_equal 'ISO-8859-2', page.parser.encoding
  end

  def test_encoding_equals_after_parser
    # document has a bad encoding information - windows-1255
    page = util_page BAD
    page.parser

    # autodetection sets encoding to windows-1255
    assert_equal 'windows-1255', page.encoding
    # believe in yourself, not machine
    assert_equal false, page.encoding_error?

    # encoding is wrong, so user wants to force ISO-8859-2
    page.encoding = 'ISO-8859-2'

    assert_equal false, page.encoding_error?
    assert_equal 'ISO-8859-2', page.encoding
    assert_equal 'ISO-8859-2', page.parser.encoding
  end

  def test_frames_with
    page = @mech.get("http://localhost/frame_test.html")
    assert_equal(3, page.frames.size)

    find_orig = page.frames.find_all { |f| f.name == 'frame1' }

    find1 = page.frames_with(:name => 'frame1')

    find_orig.zip(find1).each { |a,b|
      assert_equal(a, b)
    }
  end

  def test_links_with_dom_id
    page = @mech.get("http://localhost/tc_links.html")
    link = page.links_with(:dom_id => 'bold_aaron_link')
    link_by_id = page.links_with(:id => 'bold_aaron_link')
    assert_equal(1, link.length)
    assert_equal('Aaron Patterson', link.first.text)
    assert_equal(link, link_by_id)
  end

  def test_links_with_dom_class
    page = @mech.get("http://localhost/tc_links.html")
    link = page.links_with(:dom_class => 'thing_link')
    link_by_class = page.links_with(:class => 'thing_link')
    assert_equal(1, link.length)
    assert_equal(link, link_by_class)
  end

  def test_link_with_encoded_space
    page = @mech.get("http://localhost/tc_links.html")
    link = page.link_with(:text => 'encoded space')
    page = @mech.click link
  end

  def test_link_with_space
    page = @mech.get("http://localhost/tc_links.html")
    link = page.link_with(:text => 'not encoded space')
    page = @mech.click link
  end

  def test_link_with_unusual_characters
    page = @mech.get("http://localhost/tc_links.html")
    link = page.link_with(:text => 'unusual characters')

    @mech.click link

    # HACK no assertion
  end

  def test_links
    page = @mech.get("http://localhost/find_link.html")
    assert_equal(18, page.links.length)
  end unless RUBY_ENGINE == 'jruby'  # NekoHTML does not parse FRAME outside of FRAMESET

  def test_links_with_bold
    page = @mech.get("http://localhost/tc_links.html")
    link = page.links_with(:text => /Bold Dude/)
    assert_equal(1, link.length)
    assert_equal('Bold Dude', link.first.text)
    assert_equal [], link.first.rel
    assert !link.first.rel?('me')
    assert !link.first.rel?('nofollow')

    link = page.links_with(:text => 'Aaron James Patterson')
    assert_equal(1, link.length)
    assert_equal('Aaron James Patterson', link.first.text)
    assert_equal ['me'], link.first.rel
    assert link.first.rel?('me')
    assert !link.first.rel?('nofollow')

    link = page.links_with(:text => 'Aaron Patterson')
    assert_equal(1, link.length)
    assert_equal('Aaron Patterson', link.first.text)
    assert_equal ['me', 'nofollow'], link.first.rel
    assert link.first.rel?('me')
    assert link.first.rel?('nofollow')

    link = page.links_with(:text => 'Ruby Rocks!')
    assert_equal(1, link.length)
    assert_equal('Ruby Rocks!', link.first.text)
  end

  def test_meta_refresh
    page = @mech.get("http://localhost/find_link.html")
    assert_equal(3, page.meta_refresh.length)
    assert_equal(%w{
      http://www.drphil.com/
      http://www.upcase.com/
      http://tenderlovemaking.com/ }.sort,
      page.meta_refresh.map { |x| x.href.downcase }.sort)
  end

  def test_title
    page = util_page

    assert_equal('hi', page.title)
  end

  def test_title_none
    page = util_page '' # invalid HTML

    assert_nil(page.title)
  end

  def test_page_decoded_with_charset
    page = util_page @body, 'content-type' => 'text/html; charset=EUC-JP'

    assert_equal 'EUC-JP', page.encoding
    assert_equal 'EUC-JP', page.parser.encoding
  end

  def test_form
    page  = @mech.get("http://localhost/tc_form_action.html")

    form = page.form(:name => 'post_form1')
    assert form
    yielded = false

    form = page.form(:name => 'post_form1') { |f|
      yielded = true
      assert f
      assert_equal(form, f)
    }

    assert yielded

    form_by_action = page.form(:action => '/form_post?a=b&b=c')
    assert form_by_action
    assert_equal(form, form_by_action)
  end

end

