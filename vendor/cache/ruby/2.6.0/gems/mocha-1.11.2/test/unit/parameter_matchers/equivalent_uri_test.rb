require File.expand_path('../../../test_helper', __FILE__)
require 'mocha/parameter_matchers/equivalent_uri'

class EquivalentUriMatchesTest < Mocha::TestCase
  include Mocha::ParameterMatchers

  def test_should_match_identical_uri
    matcher = equivalent_uri('http://example.com/foo?a=1&b=2')
    assert matcher.matches?(['http://example.com/foo?a=1&b=2'])
  end

  def test_should_match_uri_with_rearranged_query_string
    matcher = equivalent_uri('http://example.com/foo?b=2&a=1')
    assert matcher.matches?(['http://example.com/foo?a=1&b=2'])
  end

  def test_should_not_match_uri_with_different_query_string
    matcher = equivalent_uri('http://example.com/foo?a=1')
    assert !matcher.matches?(['http://example.com/foo?a=1&b=2'])
  end

  def test_should_not_match_uri_when_no_query_string_expected
    matcher = equivalent_uri('http://example.com/foo')
    assert !matcher.matches?(['http://example.com/foo?a=1&b=2'])
  end

  def test_should_not_match_uri_with_different_domain
    matcher = equivalent_uri('http://a.example.com/foo?a=1&b=2')
    assert !matcher.matches?(['http://b.example.com/foo?a=1&b=2'])
  end

  def test_should_match_uri_without_scheme_and_domain
    matcher = equivalent_uri('/foo?a=1&b=2')
    assert matcher.matches?(['/foo?a=1&b=2'])
  end

  def test_should_match_uri_with_query_string_containing_blank_value
    matcher = equivalent_uri('http://example.com/foo?a=&b=2')
    assert matcher.matches?(['http://example.com/foo?a=&b=2'])
  end
end
