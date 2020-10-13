require 'mechanize/test_case'

class TestMechanizePageImage < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/'
    @src = (@uri + 'a.jpg').to_s

    @empty_page = Mechanize::Page.new(@uri, nil, '', 200, @mech)
  end

  def img attributes
    img = node 'img', attributes

    Mechanize::Page::Image.new img, @empty_page
  end

  def test_initialize
    image = img("src" => "a.jpg", "alt" => "alt", "width" => "100",
                "height" => "200", "title" => "title", "id" => "id",
                "class" => "class")

    assert_equal "a.jpg", image.src
    assert_equal "alt",   image.alt
    assert_equal "100",   image.width
    assert_equal "200",   image.height
    assert_equal "title", image.title
    assert_equal "id",    image.dom_id
    assert_equal "class", image.dom_class
  end

  def test_initialize_no_attributes
    image = img({})

    assert_nil image.src
    assert_nil image.alt
    assert_nil image.width
    assert_nil image.height
    assert_nil image.title
    assert_nil image.dom_id
    assert_nil image.dom_class
  end

  def test_caption
    assert_equal "",      img("src" => @src).caption
    assert_equal "alt",   img("src" => @src, "alt" => "alt").caption
    assert_equal "title", img("src" => @src, "title" => "title").caption
    assert_equal "title", img("src" => @src,
                              "alt" => "alt", "title" => "title").caption
  end

  def test_url
    assert_equal ".jpg", img('src' => @src).extname
    assert_equal "http://example/a.jpg", img('src' => @src).url.to_s
    assert_equal "http://example/a%20.jpg", img('src' => 'http://example/a .jpg' ).url.to_s
  end

  def test_url_base
    page = html_page <<-BODY
<head>
  <base href="http://other.example/">
</head>
<body>
  <img src="a.jpg">
</body>
    BODY

    assert_equal "http://other.example/a.jpg", page.images.first.url
  end

  def test_extname
    assert_equal ".jpg", img("src" => "a.jpg").extname
    assert_equal ".PNG", img("src" => "a.PNG").extname
    assert_equal ".aaa", img("src" => "unknown.aaa").extname
    assert_equal "",     img("src" => "nosuffiximage").extname

    assert_nil img("width" => "1", "height" => "1").extname

    assert_equal ".jpg", img("src" => "a.jpg?cache_buster").extname
  end

  def test_mime_type
    assert_equal "image/jpeg", img("src" => "a.jpg").mime_type
    assert_equal "image/png",  img("src" => "a.PNG").mime_type

    assert_nil img("src" => "unknown.aaa").mime_type
    assert_nil img("src" => "nosuffiximage").mime_type
  end

  def test_fetch
    image = img "src" => "http://localhost/button.jpg"

    fetched = image.fetch

    assert_equal fetched, @mech.page
    assert_equal "http://localhost/button.jpg", fetched.uri.to_s
    assert_equal "http://example/", requests.first['Referer']
    assert @mech.visited? "http://localhost/button.jpg"
  end

  def test_fetch_referer_http_page_rel_src
    #            | rel-src http-src https-src
    # http page  | *page*    page     page
    # https page |  page     empty    empty
    page = html_page '<img src="./button.jpg">'
    page.images.first.fetch

    assert_equal 'http', page.uri.scheme
    assert_equal true, page.images.first.relative?
    assert_equal "http://example/", requests.first['Referer']
  end

  def test_fetch_referer_http_page_abs_src
    #            | rel-src http-src https-src
    # http page  |  page    *page*    *page*
    # https page |  page     empty    empty
    page = html_page '<img src="http://localhost/button.jpg">'
    page.images.first.fetch

    assert_equal 'http', page.uri.scheme
    assert_equal false, page.images.first.relative?
    assert_equal "http://example/", requests.first['Referer']
  end

  def test_fetch_referer_https_page_rel_src
    #            | rel-src http-src https-src
    # http page  |  page     page     page
    # https page | *page*    empty    empty
    page = html_page '<img src="./button.jpg">'
    page.uri = URI 'https://example/'
    page.images.first.fetch

    assert_equal 'https', page.uri.scheme
    assert_equal true, page.images.first.relative?
    assert_equal "https://example/", requests.first['Referer']
  end

  def test_fetch_referer_https_page_abs_src
    #            | rel-src http-src https-src
    # http page  |  page     page     page
    # https page |  page    *empty*  *empty*
    page = html_page '<img src="http://localhost/button.jpg">'
    page.uri = URI 'https://example/'
    page.images.first.fetch

    assert_equal 'https', page.uri.scheme
    assert_equal false, page.images.first.relative?
    assert_nil requests.first['Referer']
  end

  def test_image_referer_http_page_abs_src
    page = html_page '<img src="http://localhost/button.jpg">'

    assert_equal 'http', page.uri.scheme
    assert_equal @uri, page.images.first.image_referer.uri
  end

  def test_image_referer_http_page_rel_src
    page = html_page '<img src="./button.jpg">'

    assert_equal 'http', page.uri.scheme
    assert_equal @uri, page.images.first.image_referer.uri
  end

  def test_image_referer_https_page_abs_src
    page = html_page '<img src="http://localhost/button.jpg">'
    page.uri = URI 'https://example/'

    assert_equal 'https', page.uri.scheme
    assert_nil page.images.first.image_referer.uri
  end

  def test_image_referer_https_page_rel_src
    page = html_page '<img src="./button.jpg">'
    page.uri = URI 'https://example/'

    assert_equal 'https', page.uri.scheme
    assert_equal URI('https://example/'), page.images.first.image_referer.uri
  end

  def test_no_src_attribute
    page = html_page '<img width="10" height="10" class="foo" />'
    page.uri = URI 'https://example/'
    assert_equal URI('https://example/'), page.images.first.url
  end

end

