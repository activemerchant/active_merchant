require File.expand_path('../../test_helper', __FILE__)

require 'mocha/yield_parameters'

class YieldParametersTest < Mocha::TestCase
  include Mocha

  def test_should_return_null_yield_parameter_group_by_default
    assert_next_invocation_yields(YieldParameters.new, [])
  end

  def test_should_return_single_yield_parameter_group
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3]])
  end

  def test_should_keep_returning_single_yield_parameter_group
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3]])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3]])
  end

  def test_should_return_consecutive_single_yield_parameter_groups
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3])
    yield_parameters.add([4, 5])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3]])
    assert_next_invocation_yields(yield_parameters, [[4, 5]])
  end

  def test_should_return_multiple_yield_parameter_group
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3], [4, 5])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3], [4, 5]])
  end

  def test_should_return_multiple_yield_parameter_group_when_arguments_are_not_arrays
    yield_parameters = YieldParameters.new
    yield_parameters.add(1, { :b => 2 }, 3)
    assert_next_invocation_yields(yield_parameters, [[1], [{ :b => 2 }], [3]])
  end

  def test_should_keep_returning_multiple_yield_parameter_group
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3], [4, 5])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3], [4, 5]])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3], [4, 5]])
  end

  def test_should_return_consecutive_multiple_yield_parameter_groups
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3], [4, 5])
    yield_parameters.add([6, 7], [8, 9, 0])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3], [4, 5]])
    assert_next_invocation_yields(yield_parameters, [[6, 7], [8, 9, 0]])
  end

  def test_should_return_consecutive_single_and_multiple_yield_parameter_groups
    yield_parameters = YieldParameters.new
    yield_parameters.add([1, 2, 3])
    yield_parameters.add([4, 5, 6], [7, 8])
    assert_next_invocation_yields(yield_parameters, [[1, 2, 3]])
    assert_next_invocation_yields(yield_parameters, [[4, 5, 6], [7, 8]])
  end

  private

  def assert_next_invocation_yields(yield_parameters, expected)
    assert_equal expected, yield_parameters.next_invocation
  end
end
