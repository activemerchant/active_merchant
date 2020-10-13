require 'mechanize/test_case'

class TestMechanizeParser < Mechanize::TestCase

  class P
    include Mechanize::Parser

    attr_accessor :filename
    attr_accessor :response
    attr_accessor :uri

    def initialize
      @uri = URI 'http://example'
      @full_path = false
    end
  end

  def setup
    super

    @parser = P.new
  end

  def test_extract_filename
    @parser.response = {}

    assert_equal 'index.html', @parser.extract_filename
  end

  def test_extract_filename_content_disposition
    @parser.uri = URI 'http://example/foo'

    @parser.response = {
      'content-disposition' => 'attachment; filename=genome.jpeg'
    }

    assert_equal 'genome.jpeg', @parser.extract_filename
  end

  def test_extract_filename_content_disposition_bad
    @parser.uri = URI 'http://example/foo'

    @parser.response = {
      'content-disposition' => "inline; filename*=UTF-8''X%20Y.jpg"
    }

    assert_equal 'foo.html', @parser.extract_filename

    @parser.response = {
      'content-disposition' => "inline; filename=\"\""
    }

    assert_equal 'foo.html', @parser.extract_filename
  end

  def test_extract_filename_content_disposition_path
    @parser.uri = URI 'http://example'

    @parser.response = {
      'content-disposition' => 'attachment; filename="../genome.jpeg"'
    }

    assert_equal 'example/genome.jpeg', @parser.extract_filename(true)

    @parser.response = {
      'content-disposition' => 'attachment; filename="foo/genome.jpeg"'
    }

    assert_equal 'example/genome.jpeg', @parser.extract_filename(true)
  end

  def test_extract_filename_content_disposition_path_windows
    @parser.uri = URI 'http://example'

    @parser.response = {
      'content-disposition' => 'attachment; filename="..\\\\genome.jpeg"'
    }

    assert_equal 'example/genome.jpeg', @parser.extract_filename(true)

    @parser.response = {
      'content-disposition' => 'attachment; filename="foo\\\\genome.jpeg"'
    }

    assert_equal 'example/genome.jpeg', @parser.extract_filename(true)
  end

  def test_extract_filename_content_disposition_full_path
    @parser.uri = URI 'http://example/foo'

    @parser.response = {
      'content-disposition' => 'attachment; filename=genome.jpeg'
    }

    assert_equal 'example/genome.jpeg', @parser.extract_filename(true)
  end

  def test_extract_filename_content_disposition_quoted
    @parser.uri = URI 'http://example'

    @parser.response = {
      'content-disposition' => 'attachment; filename="\"some \"file\""'
    }

    assert_equal '_some__file_', @parser.extract_filename
  end

  def test_extract_filename_content_disposition_special
    @parser.uri = URI 'http://example/foo'

    @parser.response = {
      'content-disposition' => 'attachment; filename="/\\\\<>:\\"|?*"'
    }

    assert_equal '_______', @parser.extract_filename

    chars = (0..12).map { |c| c.chr }.join
    chars += "\\\r"
    chars += (14..31).map { |c| c.chr }.join

    @parser.response = {
      'content-disposition' => "attachment; filename=\"#{chars}\""
    }

    assert_equal '_' * 32, @parser.extract_filename
  end

  def test_extract_filename_content_disposition_windows_special
    @parser.uri = URI 'http://example'

    windows_special = %w[
      AUX
      COM1
      COM2
      COM3
      COM4
      COM5
      COM6
      COM7
      COM8
      COM9
      CON
      LPT1
      LPT2
      LPT3
      LPT4
      LPT5
      LPT6
      LPT7
      LPT8
      LPT9
      NUL
      PRN
    ]

    windows_special.each do |special|
      @parser.response = {
        'content-disposition' => "attachment; filename=#{special}"
      }

      assert_equal "_#{special}", @parser.extract_filename
    end
  end

  def test_extract_filename_content_disposition_empty
    @parser.uri = URI 'http://example'

    @parser.response = {
      'content-disposition' => 'inline; filename="/"'
    }

    assert_equal '', @parser.extract_filename
  end

  def test_extract_filename_host
    @parser.response = {}
    @parser.uri = URI 'http://example'

    assert_equal 'example/index.html', @parser.extract_filename(true)
  end

  def test_extract_filename_special_character
    @parser.response = {}

    invisible = "\t\n\v\f\r"

    invisible.chars.each do |char|
      begin
        @parser.uri = URI "http://example/#{char}"

        assert_equal 'index.html', @parser.extract_filename, char.inspect
      rescue URI::InvalidURIError
        # ignore
      end
    end

    escaped = "<>\"\\|"

    escaped.chars.each do |char|
      escaped_char = CGI.escape char

      @parser.uri = URI "http://example/#{escaped_char}"

      assert_equal "#{escaped_char}.html", @parser.extract_filename, char
    end

    @parser.uri = URI "http://example/?"

    assert_equal 'index.html_', @parser.extract_filename, 'empty query'

    @parser.uri = URI "http://example/:"

    assert_equal '_.html', @parser.extract_filename, 'colon'

    @parser.uri = URI "http://example/*"

    assert_equal '_.html', @parser.extract_filename, 'asterisk'
  end

  def test_extract_filename_uri
    @parser.response = {}
    @parser.uri = URI 'http://example/foo'

    assert_equal 'foo.html', @parser.extract_filename

    @parser.uri += '/foo.jpg'

    assert_equal 'foo.jpg', @parser.extract_filename
  end

  def test_extract_filename_uri_full_path
    @parser.response = {}
    @parser.uri = URI 'http://example/foo'

    assert_equal 'example/foo.html', @parser.extract_filename(true)

    @parser.uri += '/foo.jpg'

    assert_equal 'example/foo.jpg', @parser.extract_filename(true)
  end

  def test_extract_filename_uri_query
    @parser.response = {}
    @parser.uri = URI 'http://example/?id=5'

    assert_equal 'index.html_id=5', @parser.extract_filename

    @parser.uri += '/foo.html?id=5'

    assert_equal 'foo.html_id=5', @parser.extract_filename
  end

  def test_extract_filename_uri_slash
    @parser.response = {}
    @parser.uri = URI 'http://example/foo/'

    assert_equal 'example/foo/index.html', @parser.extract_filename(true)

    @parser.uri += '/foo///'

    assert_equal 'example/foo/index.html', @parser.extract_filename(true)
  end

  def test_extract_filename_windows_special
    @parser.uri = URI 'http://example'
    @parser.response = {}

    windows_special = %w[
      AUX
      COM1
      COM2
      COM3
      COM4
      COM5
      COM6
      COM7
      COM8
      COM9
      CON
      LPT1
      LPT2
      LPT3
      LPT4
      LPT5
      LPT6
      LPT7
      LPT8
      LPT9
      NUL
      PRN
    ]

    windows_special.each do |special|
      @parser.uri += "/#{special}"

      assert_equal "_#{special}.html", @parser.extract_filename
    end
  end

  def test_fill_header
    @parser.fill_header 'a' => 'b'

    expected = { 'a' => 'b' }

    assert_equal expected, @parser.response
  end

  def test_fill_header_nil
    @parser.fill_header nil

    assert_empty @parser.response
  end

end

