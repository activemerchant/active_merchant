require File.expand_path('../../../test_helper', __FILE__)

require 'mocha/parameter_matchers/includes'
require 'mocha/parameter_matchers/instance_methods'
require 'mocha/parameter_matchers/has_key'
require 'mocha/parameter_matchers/regexp_matches'
require 'mocha/inspect'

class IncludesTest < Mocha::TestCase
  include Mocha::ParameterMatchers

  def test_should_match_object_including_value
    matcher = includes(:x)
    assert matcher.matches?([[:x, :y, :z]])
  end

  def test_should_match_object_including_array_value
    matcher = includes([:x])
    assert matcher.matches?([[[:x], [:y], [:z]]])
  end

  def test_should_match_object_including_all_values
    matcher = includes(:x, :y, :z)
    assert matcher.matches?([[:x, :y, :z]])
  end

  def test_should_not_match_object_that_does_not_include_value
    matcher = includes(:not_included)
    assert !matcher.matches?([[:x, :y, :z]])
  end

  def test_should_not_match_object_that_does_not_include_any_one_value
    matcher = includes(:x, :y, :z, :not_included)
    assert !matcher.matches?([[:x, :y, :z]])
  end

  def test_should_describe_matcher_with_one_item
    matcher = includes(:x)
    assert_equal 'includes(:x)', matcher.mocha_inspect
  end

  def test_should_describe_matcher_with_multiple_items
    matcher = includes(:x, :y, :z)
    assert_equal 'includes(:x, :y, :z)', matcher.mocha_inspect
  end

  def test_should_not_raise_error_on_emtpy_arguments
    matcher = includes(:x)
    assert_nothing_raised { matcher.matches?([]) }
  end

  def test_should_not_match_on_empty_arguments
    matcher = includes(:x)
    assert !matcher.matches?([])
  end

  def test_should_not_raise_error_on_argument_that_does_not_respond_to_include
    matcher = includes(:x)
    assert_nothing_raised { matcher.matches?([:x]) }
  end

  def test_should_not_match_on_argument_that_does_not_respond_to_include
    matcher = includes(:x)
    assert !matcher.matches?([:x])
  end

  def test_should_match_object_including_value_which_matches_nested_matcher
    matcher = includes(has_key(:key))
    assert matcher.matches?([[:non_matching_element, { :key => 'value' }]])
  end

  def test_should_not_match_object_which_doesnt_include_value_that_matches_nested_matcher
    matcher = includes(has_key(:key))
    assert !matcher.matches?([[:non_matching_element, { :other_key => 'other-value' }]])
  end

  def test_should_match_string_argument_containing_substring
    matcher = includes('bar')
    assert matcher.matches?(['foobarbaz'])
  end

  def test_should_not_match_string_argument_without_substring
    matcher = includes('bar')
    assert !matcher.matches?(['foobaz'])
  end

  def test_should_match_hash_argument_containing_given_key
    matcher = includes(:key)
    assert matcher.matches?([{ :thing => 1, :key => 2 }])
  end

  def test_should_not_match_hash_argument_missing_given_key
    matcher = includes(:key)
    assert !matcher.matches?([{ :thing => 1, :other => :key }])
  end

  def test_should_match_hash_when_nested_matcher_matches_key
    matcher = includes(regexp_matches(/ar/))
    assert matcher.matches?([{ 'foo' => 1, 'bar' => 2 }])
  end

  def test_should_not_match_hash_when_nested_matcher_doesn_not_match_key
    matcher = includes(regexp_matches(/az/))
    assert !matcher.matches?([{ 'foo' => 1, 'bar' => 2 }])
  end
end
