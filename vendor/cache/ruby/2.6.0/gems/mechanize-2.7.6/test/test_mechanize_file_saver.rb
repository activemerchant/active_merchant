require 'mechanize/test_case'

class TestMechanizeFileSaver < Mechanize::TestCase

  def setup
    super

    @uri = URI 'http://example'
    @io = StringIO.new 'hello world'
  end

  def test_initialize
    in_tmpdir do
      Mechanize::FileSaver.new @uri, nil, @io, 200

      assert File.exist? 'example/index.html'
    end
  end

end

