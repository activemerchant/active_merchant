require 'mechanize/test_case'

class TestMechanizePage < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example/'
  end

  def test_selector_methods
    page = html_page <<-BODY
<html>
  <meta>
  <head><title></title>
  <body>
    <span class="name" id="out">Eamonn</span>
    <span>/</span>
    <span class="name" id="bloody">Esther</span>
    <span>/</span>
    <span class="name" id="rageous">Fletcher</span>
  </body>
</html>
    BODY

    # at(css_selector), % css_selector
    assert_equal('Eamonn', page.at('#out').text)
    assert_equal('Eamonn', (page % '#out').text)

    # at(xpath_selector), % xpath_selector
    assert_equal('Esther', page.at('//span[@id="bloody"]').text)
    assert_equal('Esther', (page % '//span[@id="bloody"]').text)

    # at_css()
    assert_equal('Eamonn', page.at_css('#out').text)

    # css()
    assert_equal('Fletcher', page.css('.name')[2].text)

    # at_xpath()
    assert_equal('Esther', page.at_xpath('//span[@id="bloody"]').text)

    # xpath()
    assert_equal('Fletcher', page.xpath('//*[@class="name"]')[2].text)
  end

  def test_initialize_good_content_type
    page = Mechanize::Page.new
    assert_equal('text/html', page.content_type)

    [
      'text/html',
      'Text/HTML',
      'text/html; charset=UTF-8',
      'text/html ; charset=US-ASCII',
      'application/xhtml+xml',
      'Application/XHTML+XML',
      'application/xhtml+xml; charset=UTF-8',
      'application/xhtml+xml ; charset=US-ASCII',
    ].each { |content_type|
      page = Mechanize::Page.new(URI('http://example/'),
        { 'content-type' => content_type }, 'hello', '200')

      assert_equal(content_type, page.content_type, content_type)
    }
  end

  def test_initialize_bad_content_type
    [
      'text/xml',
      'text/xhtml',
      'text/htmlfu',
      'footext/html',
      'application/xhtml+xmlfu',
      'fooapplication/xhtml+xml',
    ].each { |content_type|
      page = Mechanize::Page.new(URI('http://example/'),
        { 'content-type' => content_type }, 'hello', '200')

      assert_equal(content_type, page.content_type, content_type)
    }
  end

  def test_frames
    page = html_page <<-BODY
<TITLE>A simple frameset document</TITLE>
<FRAMESET cols="20%, 80%">
  <FRAMESET rows="100, 200">
  <FRAME name="frame1" src="/google.html">
  <FRAME name="frame2" src="/form_test.html">
  </FRAMESET>
  <FRAMESET rows="100, 200">
  <FRAME name="frame3" src="/file_upload.html">
  <IFRAME src="http://google.com/" name="frame4"></IFRAME>
  </FRAMESET>
</FRAMESET>
    BODY

    assert_equal 3, page.frames.size
    assert_equal "frame1",       page.frames[0].name
    assert_equal "/google.html", page.frames[0].src
    assert_equal "Google",       page.frames[0].content.title

    assert_equal "frame2",          page.frames[1].name
    assert_equal "/form_test.html", page.frames[1].src
    assert_equal "Page Title",      page.frames[1].content.title

    assert_equal "frame3",            page.frames[2].name
    assert_equal "/file_upload.html", page.frames[2].src
    assert_equal "File Upload Form",  page.frames[2].content.title

    assert_equal %w[/google.html /file_upload.html], page.frames_with(search: '*[name=frame1], *[name=frame3]').map(&:src)
  end

  def test_iframes
    page = html_page <<-BODY
<TITLE>A simple frameset document</TITLE>
<FRAME name="frame1" src="/google.html">
<IFRAME src="/file_upload.html" name="frame4">
</IFRAME>
    BODY

    assert_equal 1, page.iframes.size

    assert_equal "frame4",            page.iframes.first.name
    assert_equal "/file_upload.html", page.iframes.first.src
    assert_equal "File Upload Form",  page.iframes.first.content.title
  end unless RUBY_ENGINE == 'jruby'  # NekoHTML does not parse IFRAME

  def test_image_with
    page = html_page <<-BODY
<img src="a.jpg">
<img src="b.jpg">
<img src="c.png">
    BODY

    assert_equal "http://example/b.jpg",
                 page.image_with(:src => 'b.jpg').url.to_s
  end

  def test_images_with
    page = html_page <<-BODY
<img src="a.jpg">
<img src="b.jpg">
<img src="c.png">
    BODY

    images = page.images_with(:src => /jpg\Z/).map { |img| img.url.to_s }
    assert_equal %w[http://example/a.jpg http://example/b.jpg], images
  end

  def test_links
    page = html_page <<-BODY
<a href="foo.html">
    BODY

    assert_equal page.links.first.href, "foo.html"
  end

  def test_parser_no_attributes
    page = html_page <<-BODY
<html>
  <meta>
  <head><title></title>
  <body>
    <a>Hello</a>
    <a><img /></a>
    <form>
      <input />
      <select>
        <option />
      </select>
      <textarea></textarea>
    </form>
    <frame></frame>
  </body>
</html>
    BODY

    # HACK weak assertion
    assert_kind_of Nokogiri::HTML::Document, page.root
  end

  def test_search_links
    page = html_page <<-BODY
<html>
  <meta>
  <head><title></title>
  <body>
    <span id="spany">
      <a href="b.html">b</a>
      <a href="a.html">a</a>
    </span>
    <a href="6.html">6</a>
  </body>
</html>
    BODY

    links = page.links_with(:search => "#spany a")

    assert_equal 2, links.size
    assert_equal "b.html", links[0].href
    assert_equal "b",      links[0].text

    assert_equal "a.html", links[1].href
    assert_equal "a",      links[1].text
  end

  def test_search_images
    page = html_page <<-BODY
<html>
  <meta>
  <head><title></title>
  <body>
    <img src="1.jpg" class="unpretty">
    <img src="a.jpg" class="pretty">
    <img src="b.jpg">
    <img src="c.png" class="pretty">
  </body>
</html>
    BODY

    {
      :search => "//img[@class='pretty']",
      :xpath => "//img[@class='pretty']",
      :css => "img.pretty",
      :class => "pretty",
      :dom_class => "pretty",
    }.each { |key, expr|
      images = page.images_with(key => expr)

      message = "selecting with #{key.inspect}"

      assert_equal 2, images.size
      assert_equal "pretty", images[0].dom_class, message
      assert_equal "a.jpg", images[0].src, message

      assert_equal "pretty", images[1].dom_class, message
      assert_equal "c.png", images[1].src, message
    }
  end

  def test_search_bad_selectors
    page = html_page <<-BODY
<a href="foo.html">foo</a>
<img src="foo.jpg" />
    BODY

    assert_empty page.images_with(:search => '//a')
    assert_empty page.links_with(:search => '//img')
  end

	def test_multiple_titles
		page = html_page <<-BODY
<!doctype html>
<html>
	<head>
		<title>HTML&gt;TITLE</title>
	</head>
	<body>
		<svg>
			<title>SVGTITLE</title>
			<metadata id="metadata5">
				<rdf:RDF>
					<cc:Work>
						<dc:title>RDFDCTITLE</dc:title>
					</cc:Work>
				</rdf:RDF>
			</metadata>
			<g></g>
		</svg>
	</body>
</html>
		BODY

		assert_equal page.title, "HTML>TITLE"
	end

end

