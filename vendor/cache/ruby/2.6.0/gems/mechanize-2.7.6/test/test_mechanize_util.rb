# coding: utf-8

require 'mechanize/test_case'

class TestMechanizeUtil < Mechanize::TestCase

  INPUTTED_VALUE = "テスト" # "test" in Japanese UTF-8 encoding
  CONTENT_ENCODING = 'Shift_JIS' # one of Japanese encoding
  ENCODED_VALUE = "\x83\x65\x83\x58\x83\x67".force_encoding(::Encoding::SHIFT_JIS) # "test" in Japanese Shift_JIS encoding

  ENCODING_ERRORS = [EncodingError, Encoding::ConverterNotFoundError] # and so on
  ERROR_LOG_MESSAGE = /from_native_charset: Encoding::ConverterNotFoundError: form encoding: "UTF-eight"/

  INVALID_ENCODING = 'UTF-eight'

  def setup
    super

    @MU = Mechanize::Util
    @result = "not set"
  end

  def test_from_native_charset
    @result = @MU.from_native_charset(INPUTTED_VALUE, CONTENT_ENCODING)
    assert_equal ENCODED_VALUE, @result
  end

  def test_from_native_charset_returns_nil_when_no_string
    @result = @MU.from_native_charset(nil, CONTENT_ENCODING)
    assert_nil @result
  end

  def test_from_native_charset_doesnot_convert_when_no_encoding
    @result = @MU.from_native_charset(INPUTTED_VALUE, nil)
    refute_equal ENCODED_VALUE, @result
    assert_equal INPUTTED_VALUE, @result
  end

  def test_from_native_charset_doesnot_convert_when_not_nokogiri
    parser = Mechanize.html_parser
    Mechanize.html_parser = 'Another HTML Parser'

    @result = @MU.from_native_charset(INPUTTED_VALUE, CONTENT_ENCODING)
    refute_equal ENCODED_VALUE, @result
    assert_equal INPUTTED_VALUE, @result
  ensure
    Mechanize.html_parser = parser
  end

  def test_from_native_charset_raises_error_with_bad_encoding
    assert_raises(*ENCODING_ERRORS) do
      @MU.from_native_charset(INPUTTED_VALUE, INVALID_ENCODING)
    end
  end

  def test_from_native_charset_suppress_encoding_error_when_3rd_arg_is_true
    @MU.from_native_charset(INPUTTED_VALUE, INVALID_ENCODING, true)

    # HACK no assertion
  end

  def test_from_native_charset_doesnot_convert_when_encoding_error_raised_and_ignored
    @result = @MU.from_native_charset(INPUTTED_VALUE, INVALID_ENCODING, true)

    refute_equal ENCODED_VALUE, @result
    assert_equal INPUTTED_VALUE, @result
  end

  def test_from_native_charset_logs_form_when_encoding_error_raised
    sio = StringIO.new("")
    log = Logger.new(sio)
    log.level = Logger::DEBUG

    assert_raises(*ENCODING_ERRORS) do
      @MU.from_native_charset(INPUTTED_VALUE, INVALID_ENCODING, nil, log)
    end

    assert_match ERROR_LOG_MESSAGE, sio.string
  end

  def test_from_native_charset_logs_form_when_encoding_error_is_ignored
    sio = StringIO.new("")
    log = Logger.new(sio)
    log.level = Logger::DEBUG

    @MU.from_native_charset(INPUTTED_VALUE, INVALID_ENCODING, true, log)

    assert_match ERROR_LOG_MESSAGE, sio.string
  end

  def test_self_html_unescape_entity
    assert_equal '&', @MU::html_unescape('&')
    assert_equal '&', @MU::html_unescape('&amp;')
  end

  def test_uri_escape
    assert_equal "%25", @MU.uri_escape("%")
    assert_equal "%",   @MU.uri_escape("%", /[^%]/)
  end

  def test_build_query_string_simple
    input_params = [
      [:ids, 1],
      [:action, 'delete'],
      [:ids, 5],
    ]

    expected_params = [
      ['ids', '1'],
      ['action', 'delete'],
      ['ids', '5'],
    ]

    query = @MU.build_query_string(input_params)

    assert_equal expected_params, URI.decode_www_form(query)
  end

  def test_build_query_string_complex
    input_params = {
      number: 7,
      name: "\u{6B66}\u{8005}",
      "ids[]" => [1, 3, 5, 7],
      words: ["Sing", "Now!"],
      params: { x: "50%", y: "100%", t: [80, 160] },
    }

    expected_params = [
      ['number', '7'],
      ['name', "\u{6B66}\u{8005}"],
      ['ids[]', '1'], ['ids[]', '3'], ['ids[]', '5'], ['ids[]', '7'],
      ['words', 'Sing'], ['words', 'Now!'],
      ['params[x]', '50%'],
      ['params[y]', '100%'],
      ['params[t]', '80'], ['params[t]', '160'],
    ]

    query = @MU.build_query_string(input_params)

    assert_equal expected_params, URI.decode_www_form(query)
  end
end

