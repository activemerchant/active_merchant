require File.expand_path('../../test_helper', __FILE__)
require 'mocha/cardinality'
require 'mocha/invocation'
require 'mocha/return_values'
require 'mocha/yield_parameters'

class CardinalityTest < Mocha::TestCase
  include Mocha

  def new_invocation
    Invocation.new(:irrelevant, :irrelevant)
  end

  def test_should_allow_invocations_if_invocation_count_has_not_yet_reached_maximum
    cardinality = Cardinality.new(2, 3)
    assert cardinality.invocations_allowed?
    cardinality << new_invocation
    assert cardinality.invocations_allowed?
    cardinality << new_invocation
    assert cardinality.invocations_allowed?
    cardinality << new_invocation
    assert !cardinality.invocations_allowed?
  end

  def test_should_be_satisfied_if_invocations_so_far_have_reached_required_threshold
    cardinality = Cardinality.new(2, 3)
    assert !cardinality.satisfied?
    cardinality << new_invocation
    assert !cardinality.satisfied?
    cardinality << new_invocation
    assert cardinality.satisfied?
    cardinality << new_invocation
    assert cardinality.satisfied?
  end

  def test_should_describe_cardinality_defined_using_at_least
    assert_equal 'allowed any number of times', Cardinality.at_least(0).anticipated_times
    assert_equal 'expected at least once', Cardinality.at_least(1).anticipated_times
    assert_equal 'expected at least twice', Cardinality.at_least(2).anticipated_times
    assert_equal 'expected at least 3 times', Cardinality.at_least(3).anticipated_times
  end

  def test_should_describe_cardinality_defined_using_at_most
    assert_equal 'expected at most once', Cardinality.at_most(1).anticipated_times
    assert_equal 'expected at most twice', Cardinality.at_most(2).anticipated_times
    assert_equal 'expected at most 3 times', Cardinality.at_most(3).anticipated_times
  end

  def test_should_describe_cardinality_defined_using_exactly
    assert_equal 'expected never', Cardinality.exactly(0).anticipated_times
    assert_equal 'expected exactly once', Cardinality.exactly(1).anticipated_times
    assert_equal 'expected exactly twice', Cardinality.exactly(2).anticipated_times
    assert_equal 'expected exactly 3 times', Cardinality.exactly(3).anticipated_times
  end

  def test_should_describe_cardinality_defined_using_times_with_range
    assert_equal 'expected between 2 and 4 times', Cardinality.times(2..4).anticipated_times
    assert_equal 'expected between 1 and 3 times', Cardinality.times(1..3).anticipated_times
  end

  def test_should_need_verifying
    assert Cardinality.exactly(2).needs_verifying?
    assert Cardinality.at_least(3).needs_verifying?
    assert Cardinality.at_most(2).needs_verifying?
    assert Cardinality.times(4).needs_verifying?
    assert Cardinality.times(2..4).needs_verifying?
  end

  def test_should_not_need_verifying
    assert_equal false, Cardinality.at_least(0).needs_verifying?
  end
end
