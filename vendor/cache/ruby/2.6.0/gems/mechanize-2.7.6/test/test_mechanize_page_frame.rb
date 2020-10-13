require 'mechanize/test_case'

class TestMechanizePageFrame < Mechanize::TestCase

  def test_content
    page = page 'http://example/referer'
    frame = node 'frame', 'name' => 'frame1', 'src' => 'http://example/'
    frame = Mechanize::Page::Frame.new frame, @mech, page

    frame.content

    assert_equal 'http://example/referer', requests.first['Referer']
  end

end

