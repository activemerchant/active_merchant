require File.expand_path('../acceptance_test_helper', __FILE__)

class YieldingTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_yields_when_stubbed_method_is_invoked
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).yields
      yielded = false
      m.foo { yielded = true }
      assert yielded
    end
    assert_passed(test_result)
  end

  def test_raises_local_jump_error_if_instructed_to_yield_but_no_block_given
    test_result = run_as_test do
      Mocha::Configuration.override(:reinstate_undocumented_behaviour_from_v1_9 => false) do
        m = mock('m')
        m.stubs(:foo).yields
        assert_raises(LocalJumpError) { m.foo }
      end
    end
    assert_passed(test_result)
  end

  def test_yields_when_block_expected_and_block_given
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).with_block_given.yields
      m.stubs(:foo).with_no_block_given.returns(:bar)
      yielded = false
      m.foo { yielded = true }
      assert yielded
    end
    assert_passed(test_result)
  end

  def test_returns_when_no_block_expected_and_no_block_given
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).with_block_given.yields
      m.stubs(:foo).with_no_block_given.returns(:bar)
      assert_equal :bar, m.foo
    end
    assert_passed(test_result)
  end

  def test_yields_values_when_stubbed_method_is_invoked
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).yields(0, 1)
      yielded = []
      m.foo { |*args| yielded << args }
      assert_equal [[0, 1]], yielded
    end
    assert_passed(test_result)
  end

  def test_yields_different_values_on_consecutive_invocations
    test_result = run_as_test do
      m = mock('m')
      m.stubs(:foo).yields(0, 1).then.yields(2, 3)
      yielded = []
      m.foo { |*args| yielded << args }
      m.foo { |*args| yielded << args }
      assert_equal [[0, 1], [2, 3]], yielded
    end
    assert_passed(test_result)
  end
end
