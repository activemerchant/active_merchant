require 'mechanize/test_case'

class TestMechanizeHttpContentDispositionParser < Mechanize::TestCase

  def setup
    super

    @parser = Mechanize::HTTP::ContentDispositionParser.new
  end

  def test_parse
    now = Time.at Time.now.to_i

    content_disposition = @parser.parse \
      'attachment;' \
      'filename=value;' \
      "creation-date=\"#{now.rfc822}\";" \
      "modification-date=\"#{(now + 1).rfc822}\";" \
      "read-date=\"#{(now + 2).rfc822}\";" \
      'size=5;' \
      'arbitrary=value'

    assert_equal 'attachment', content_disposition.type
    assert_equal 'value',      content_disposition.filename
    assert_equal now,          content_disposition.creation_date
    assert_equal((now + 1),    content_disposition.modification_date)
    assert_equal((now + 2),    content_disposition.read_date)
    assert_equal 5,            content_disposition.size
    expected = { 'arbitrary' => 'value' }
    assert_equal expected,     content_disposition.parameters
  end

  def test_parse_header
    content_disposition = @parser.parse \
      'content-disposition: attachment;filename=value', true

    assert_equal 'attachment', content_disposition.type
    assert_equal 'value',      content_disposition.filename
  end

  def test_parse_no_type
    content_disposition = @parser.parse 'filename=value'

    assert_nil            content_disposition.type
    assert_equal 'value', content_disposition.filename
  end

  def test_parse_semicolons
    content_disposition = @parser.parse 'attachment;;filename=value'

    assert_equal 'attachment', content_disposition.type
    assert_equal 'value',      content_disposition.filename
  end

  def test_parse_quoted_size
    content_disposition = @parser.parse 'size="5"'

    assert_equal 5, content_disposition.size
  end

  def test_rfc_2045_quoted_string
    @parser.scanner = StringScanner.new '"text"'

    string = @parser.rfc_2045_quoted_string

    assert_equal 'text', string
  end

  def test_rfc_2045_quoted_string_bad
    @parser.scanner = StringScanner.new '"text'

    assert_nil @parser.rfc_2045_quoted_string
  end

  def test_rfc_2045_quoted_string_crlf
    @parser.scanner = StringScanner.new "\"multiline\\\r\n\ttext\""

    string = @parser.rfc_2045_quoted_string

    assert_equal "multiline\r\n\ttext", string
  end

  def test_rfc_2045_quoted_string_escape
    @parser.scanner = StringScanner.new "\"escape\\ text\""

    string = @parser.rfc_2045_quoted_string

    assert_equal 'escape text', string
  end

  def test_rfc_2045_quoted_string_escape_bad
    @parser.scanner = StringScanner.new '"escape\\'

    string = @parser.rfc_2045_quoted_string

    assert_nil string
  end

  def test_rfc_2045_quoted_string_folded
    @parser.scanner = StringScanner.new "\"multiline\r\n\ttext\""

    string = @parser.rfc_2045_quoted_string

    assert_equal 'multiline text', string
  end

  def test_rfc_2045_quoted_string_quote
    @parser.scanner = StringScanner.new '"escaped \\" here"'

    string = @parser.rfc_2045_quoted_string

    assert_equal 'escaped " here', string
  end

  def test_rfc_2045_quoted_string_quote_end
    @parser.scanner = StringScanner.new '"end \\""'

    string = @parser.rfc_2045_quoted_string

    assert_equal 'end "', string
  end

  def test_parse_uppercase
    content_disposition = @parser.parse \
      'content-disposition: attachment; Filename=value', true

    assert_equal 'attachment', content_disposition.type
    assert_equal 'value',      content_disposition.filename
  end

  def test_parse_filename_starting_with_escaped_quote
    content_disposition = @parser.parse \
      'content-disposition: attachment; Filename="\"value\""', true

    assert_equal '"value"', content_disposition.filename
  end

end

