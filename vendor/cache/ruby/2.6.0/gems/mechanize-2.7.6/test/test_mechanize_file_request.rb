require 'mechanize/test_case'

class TestMechanizeFileRequest < Mechanize::TestCase

  def setup
    @uri = URI.parse 'file:///nonexistent'

    @r = Mechanize::FileRequest.new @uri
  end

  def test_initialize
    assert_equal @uri, @r.uri
    assert_equal '/nonexistent', @r.path

    assert_respond_to @r, :[]=
    assert_respond_to @r, :add_field
    assert_respond_to @r, :each_header
  end

  def test_response_body_permitted_eh
    assert @r.response_body_permitted?
  end

end

