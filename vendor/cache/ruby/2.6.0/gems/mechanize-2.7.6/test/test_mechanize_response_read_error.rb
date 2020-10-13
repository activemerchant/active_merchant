require 'mechanize/test_case'

class TestMechanizeResponseReadError < Mechanize::TestCase

  def setup
    super

    @error = 'error message'
    @response = Response.new
    @response['content-length'] = 3
    @body_io = StringIO.new 'body'
  end

  def test_force_parse
    @response['content-type'] = 'text/html'
    uri = URI 'http://example/'

    e = Mechanize::ResponseReadError.new @error, @response, @body_io, uri, @mech

    page = e.force_parse

    assert_kind_of Mechanize::Page, page
    assert_equal 'body',            page.body
    assert_equal @mech,             page.mech
  end

end

