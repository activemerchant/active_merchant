require File.expand_path('../acceptance_test_helper', __FILE__)
require 'mocha/configuration'

class MultipleYieldingTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_yields_values_multiple_times_when_stubbed_method_is_invoked
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).multiple_yields([1], [2, 3])
      yielded = []
      m.foo { |*args| yielded << args }
      assert_equal [[1], [2, 3]], yielded
    end
    assert_passed(test_result)
  end

  def test_yields_values_multiple_times_when_multiple_yields_arguments_are_not_arrays
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).multiple_yields(1, { :b => 2 }, '3')
      yielded = []
      m.foo { |*args| yielded << args }
      assert_equal [[1], [{ :b => 2 }], ['3']], yielded
    end
    assert_passed(test_result)
  end

  def test_raises_local_jump_error_if_instructed_to_multiple_yield_but_no_block_given
    test_result = run_as_test do
      Mocha::Configuration.override(:reinstate_undocumented_behaviour_from_v1_9 => false) do
        m = mock('m')
        m.stubs(:foo).multiple_yields([])
        assert_raises(LocalJumpError) { m.foo }
      end
    end
    assert_passed(test_result)
  end

  def test_yields_different_values_on_consecutive_invocations
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).multiple_yields([0], [1, 2]).then.multiple_yields([3], [4, 5])
      yielded = []
      m.foo { |*args| yielded << args }
      m.foo { |*args| yielded << args }
      assert_equal [[0], [1, 2], [3], [4, 5]], yielded
    end
    assert_passed(test_result)
  end
end
