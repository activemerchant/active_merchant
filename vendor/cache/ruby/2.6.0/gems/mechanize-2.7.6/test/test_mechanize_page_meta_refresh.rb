require 'mechanize/test_case'

class TestMechanizePageMetaRefresh < Mechanize::TestCase

  def setup
    super

    @MR = Mechanize::Page::MetaRefresh

    @uri = URI 'http://example/here/'
  end

  def util_page delay, uri
    body = <<-BODY
<head><meta http-equiv="refresh" content="#{delay};url=#{uri}"></head>
    BODY

    Mechanize::Page.new(@uri, nil, body, 200, @mech)
  end

  def util_meta_refresh page
    node = page.search('meta').first
    @MR.from_node node, page
  end

  def test_class_parse
    delay, uri, link_self = @MR.parse "0; url=http://localhost:8080/path", @uri
    assert_equal "0", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self

    delay, uri, link_self =
      @MR.parse "100.001; url=http://localhost:8080/path", @uri
    assert_equal "100.001", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self

    delay, uri, link_self =
      @MR.parse "0; url='http://localhost:8080/path'", @uri
    assert_equal "0", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self

    delay, uri, link_self =
      @MR.parse "0; url=\"http://localhost:8080/path\"", @uri
    assert_equal "0", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self

    delay, uri, link_self = @MR.parse "0; url=", @uri
    assert_equal "0", delay
    assert_equal "http://example/here/", uri.to_s
    assert link_self

    delay, uri, link_self = @MR.parse "0", @uri
    assert_equal "0", delay
    assert_equal "http://example/here/", uri.to_s
    assert link_self

    delay, uri, link_self = @MR.parse "   0;   ", @uri
    assert_equal "0", delay
    assert_equal "http://example/here/", uri.to_s
    assert link_self

    delay, uri, link_self = @MR.parse "   0 ;   ", @uri
    assert_equal "0", delay
    assert_equal "http://example/here/", uri.to_s
    assert link_self

    delay, uri, link_self = @MR.parse "0; UrL=http://localhost:8080/path", @uri
    assert_equal "0", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self

    delay, uri, link_self = @MR.parse "0 ; UrL = http://localhost:8080/path", @uri
    assert_equal "0", delay
    assert_equal "http://localhost:8080/path", uri.to_s
    refute link_self
  end

  def test_class_parse_funky
    delay, uri, link_self = @MR.parse "0; url=/funky?<b>Welcome<%2Fb>", @uri

    assert_equal "0", delay
    assert_equal "http://example/funky?%3Cb%3EWelcome%3C%2Fb%3E",
                 uri.to_s

    refute link_self
  end

  def test_class_from_node
    page = util_page 5, 'http://b.example'
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_equal 'http://b.example', link.href

    page = util_page 5, 'http://example/a'
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_equal 'http://example/a', link.href

    page = util_page 5, 'test'
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_equal 'test', link.href

    page = util_page 5, '/test'
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_equal '/test', link.href

    page = util_page 5, nil
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_nil link.href

    page = util_page 5, @uri
    link = util_meta_refresh page
    assert_equal 5, link.delay
    assert_equal 'http://example/here/', link.href
  end

  def test_class_from_node_no_content
    body = <<-BODY
<head><meta http-equiv="refresh"></head>
    BODY

    page = Mechanize::Page.new(@uri, nil, body, 200, @mech)

    assert_nil util_meta_refresh page
  end

  def test_class_from_node_not_refresh
    body = <<-BODY
<head><meta http-equiv="other-thing" content="0;"></head>
    BODY

    page = Mechanize::Page.new(@uri, nil, body, 200, @mech)

    assert_nil util_meta_refresh page
  end

  def test_meta_refresh_click_sends_no_referer
    page = util_page 0, '/referer'
    link = util_meta_refresh page
    refreshed = link.click
    assert_equal '', refreshed.body
  end
end

