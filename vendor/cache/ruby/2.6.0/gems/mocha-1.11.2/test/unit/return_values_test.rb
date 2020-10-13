require File.expand_path('../../test_helper', __FILE__)

require 'mocha/invocation'
require 'mocha/return_values'

class ReturnValuesTest < Mocha::TestCase
  include Mocha

  def new_invocation
    Invocation.new(:irrelevant, :irrelevant)
  end

  def test_should_return_nil
    values = ReturnValues.new
    assert_nil values.next(new_invocation)
  end

  def test_should_keep_returning_nil
    values = ReturnValues.new
    values.next(new_invocation)
    assert_nil values.next(new_invocation)
    assert_nil values.next(new_invocation)
  end

  def test_should_return_evaluated_single_return_value
    values = ReturnValues.new(SingleReturnValue.new('value'))
    assert_equal 'value', values.next(new_invocation)
  end

  def test_should_keep_returning_evaluated_single_return_value
    values = ReturnValues.new(SingleReturnValue.new('value'))
    values.next(new_invocation)
    assert_equal 'value', values.next(new_invocation)
    assert_equal 'value', values.next(new_invocation)
  end

  def test_should_return_consecutive_evaluated_single_return_values
    values = ReturnValues.new(SingleReturnValue.new('value_1'), SingleReturnValue.new('value_2'))
    assert_equal 'value_1', values.next(new_invocation)
    assert_equal 'value_2', values.next(new_invocation)
  end

  def test_should_keep_returning_last_of_consecutive_evaluated_single_return_values
    values = ReturnValues.new(SingleReturnValue.new('value_1'), SingleReturnValue.new('value_2'))
    values.next(new_invocation)
    values.next(new_invocation)
    assert_equal 'value_2', values.next(new_invocation)
    assert_equal 'value_2', values.next(new_invocation)
  end

  def test_should_build_single_return_values_for_each_values
    values = ReturnValues.build('value_1', 'value_2', 'value_3').values
    assert_equal 'value_1', values[0].evaluate(new_invocation)
    assert_equal 'value_2', values[1].evaluate(new_invocation)
    assert_equal 'value_3', values[2].evaluate(new_invocation)
  end

  def test_should_combine_two_sets_of_return_values
    values1 = ReturnValues.build('value_1')
    values2 = ReturnValues.build('value_2a', 'value_2b')
    values = (values1 + values2).values
    assert_equal 'value_1', values[0].evaluate(new_invocation)
    assert_equal 'value_2a', values[1].evaluate(new_invocation)
    assert_equal 'value_2b', values[2].evaluate(new_invocation)
  end
end
