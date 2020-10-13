require 'mechanize/test_case'

class TestMechanizeRedirectLimitReachedError < Mechanize::TestCase

  def test_to_s
    page = fake_page

    error = Mechanize::ElementNotFoundError.new(page, :element, :conditions)

    assert_match(/element/, error.to_s)
    assert_match(/conditions/, error.to_s)
  end

end

