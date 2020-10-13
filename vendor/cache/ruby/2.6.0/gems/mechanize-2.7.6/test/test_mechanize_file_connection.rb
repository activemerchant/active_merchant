require 'mechanize/test_case'

class TestMechanizeFileConnection < Mechanize::TestCase

  def test_request
    uri = URI.parse "file://#{File.expand_path __FILE__}"
    conn = Mechanize::FileConnection.new

    body = ''

    conn.request uri, nil do |response|
      response.read_body do |part|
        body << part
      end
    end

    assert_equal File.read(__FILE__), body
  end

end

