require 'mechanize/test_case'

class TestMechanizeFileResponse < Mechanize::TestCase

  def test_content_type
    Tempfile.open %w[pi .nothtml] do |tempfile|
      res = Mechanize::FileResponse.new tempfile.path
      assert_nil res['content-type']
    end

    Tempfile.open %w[pi .xhtml] do |tempfile|
      res = Mechanize::FileResponse.new tempfile.path
      assert_equal 'text/html', res['content-type']
    end

    Tempfile.open %w[pi .html] do |tempfile|
      res = Mechanize::FileResponse.new tempfile.path
      assert_equal 'text/html', res['Content-Type']
    end
  end

end

