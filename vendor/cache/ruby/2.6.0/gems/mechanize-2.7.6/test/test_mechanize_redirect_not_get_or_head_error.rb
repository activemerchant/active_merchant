require 'mechanize/test_case'

class TestMechanizeRedirectNotGetOrHead < Mechanize::TestCase

  def test_to_s
    page = fake_page

    error = Mechanize::RedirectNotGetOrHeadError.new(page, :put)

    assert_match(/ PUT /, error.to_s)
  end

end

