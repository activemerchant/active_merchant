# coding: utf-8
require 'mechanize/test_case'

class TestMechanizeFormEncoding < Mechanize::TestCase

  # See also: tests of Util.from_native_charset
  # Encoding test should do with non-utf-8 characters

  INPUTTED_VALUE = "テスト" # "test" in Japanese UTF-8 encoding
  CONTENT_ENCODING = 'Shift_JIS' # one of Japanese encoding
  encoded_value = "\x83\x65\x83\x58\x83\x67".force_encoding(::Encoding::SHIFT_JIS) # "test" in Japanese Shift_JIS encoding
  EXPECTED_QUERY = "first_name=#{CGI.escape(encoded_value)}&first_name=&gender=&green%5Beggs%5D="

  ENCODING_ERRORS = [EncodingError, Encoding::ConverterNotFoundError] # and so on

  ENCODING_LOG_MESSAGE = /INFO -- : form encoding: Shift_JIS/
  INVALID_ENCODING = 'UTF-eight'

  def set_form_with_encoding(enc)
    page = @mech.get("http://localhost/form_set_fields.html")
    form = page.forms.first
    form.encoding = enc
    form['first_name'] = INPUTTED_VALUE
    form
  end

  def test_form_encoding_returns_accept_charset
    page = @mech.get("http://localhost/rails_3_encoding_hack_form_test.html")
    form = page.forms.first
    accept_charset = form.form_node['accept-charset']

    assert accept_charset
    assert_equal accept_charset, form.encoding
    refute_equal page.encoding, form.encoding
  end

  def test_form_encoding_returns_page_encoding_when_no_accept_charset
    page = @mech.get("http://localhost/form_set_fields.html")
    form = page.forms.first
    accept_charset = form.form_node['accept-charset']

    assert_nil accept_charset
    refute_equal accept_charset, form.encoding
    assert_equal page.encoding, form.encoding
  end

  def test_form_encoding_equals_sets_new_encoding
    page = @mech.get("http://localhost/form_set_fields.html")
    form = page.forms.first

    refute_equal CONTENT_ENCODING, form.encoding

    form.encoding = CONTENT_ENCODING

    assert_equal CONTENT_ENCODING, form.encoding
  end

  def test_form_encoding_returns_nil_when_no_page_in_initialize
    # this sequence is seen at Mechanize#post(url, query_hash)

    node = {}
    # Create a fake form
    class << node
      def search(*args); []; end
    end
    node['method'] = 'POST'
    node['enctype'] = 'application/x-www-form-urlencoded'
    form = Mechanize::Form.new(node)

    assert_nil form.encoding
  end

  def test_post_form_with_form_encoding
    form = set_form_with_encoding CONTENT_ENCODING
    form.submit

    # we can not use "links.find{|l| l.text == 'key:val'}" assertion here
    # because the link text encoding is always UTF-8 regaredless of html encoding
    assert EXPECTED_QUERY, @mech.page.at('div#query').inner_text
  end

  def test_post_form_with_problematic_encoding
    form = set_form_with_encoding INVALID_ENCODING

    assert_raises(*ENCODING_ERRORS){ form.submit }
  end

  def test_form_ignore_encoding_error_is_true
    form = set_form_with_encoding INVALID_ENCODING
    form.ignore_encoding_error = true

    form.submit

    # HACK no assertions
  end

  def test_post_form_logs_form_encoding
    sio = StringIO.new
    @mech.log = Logger.new(sio)
    @mech.log.level = Logger::INFO

    form = set_form_with_encoding CONTENT_ENCODING
    form.submit

    assert_match ENCODING_LOG_MESSAGE, sio.string

    @mech.log = nil
  end
end
