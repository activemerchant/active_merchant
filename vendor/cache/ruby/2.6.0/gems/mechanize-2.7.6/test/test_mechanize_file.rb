require 'mechanize/test_case'

class TestMechanizeFile < Mechanize::TestCase

  def setup
    super

    @parser = Mechanize::File
  end

  def test_save
    uri = URI 'http://example/name.html'
    page = Mechanize::File.new uri, nil, '0123456789'

    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        filename = page.save 'test.html'

        assert File.exist? 'test.html'
        assert_equal '0123456789', File.read('test.html')
        assert_equal "test.html", filename

        filename = page.save 'test.html'

        assert File.exist? 'test.html.1'
        assert_equal '0123456789', File.read('test.html.1')
        assert_equal "test.html.1", filename

        filename = page.save 'test.html'

        assert File.exist? 'test.html.2'
        assert_equal '0123456789', File.read('test.html.2')
        assert_equal "test.html.2", filename
      end
    end
  end

  def test_save_default
    uri = URI 'http://example/test.html'
    page = Mechanize::File.new uri, nil, ''

    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        filename = page.save

        assert File.exist? 'test.html'
        assert_equal "test.html", filename

        filename = page.save

        assert File.exist? 'test.html.1'
        assert_equal "test.html.1", filename

        filename = page.save

        assert File.exist? 'test.html.2'
        assert_equal "test.html.2", filename
      end
    end
  end

  def test_save_default_dots
    uri = URI 'http://localhost/../test.html'
    page = Mechanize::File.new uri, nil, ''

    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        filename = page.save
        assert File.exist? 'test.html'
        assert_equal "test.html", filename

        filename = page.save
        assert File.exist? 'test.html.1'
        assert_equal "test.html.1", filename
      end
    end
  end

  def test_filename
    uri = URI 'http://localhost/test.html'
    page = Mechanize::File.new uri, nil, ''

    assert_equal "test.html", page.filename
  end

  def test_save_overwrite
    uri = URI 'http://example/test.html'
    page = Mechanize::File.new uri, nil, ''

    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        filename = page.save 'test.html'

        assert File.exist? 'test.html'
        assert_equal "test.html", filename

        filename = page.save! 'test.html'

        assert File.exist? 'test.html'
        refute File.exist? 'test.html.1'
        assert_equal "test.html", filename
      end
    end
  end

end

