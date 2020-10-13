require File.expand_path('../acceptance_test_helper', __FILE__)
require 'deprecation_disabler'

class MockBuiltWithFirstArgumentTypeBeingStringTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_mock_built_with_single_symbol_argument_with_satisfied_expectation
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        m = mock(:my_method)
        assert_nil m.my_method
      end
      expected_warning = 'Explicitly include `my_method` in Hash of expected methods vs return values, e.g. `mock(:my_method => nil)`.'
      assert_equal expected_warning, Mocha::Deprecation.messages.last
    end
    assert_passed(test_result)
  end

  def test_mock_built_with_single_symbol_argument_with_unsatisfied_expectation
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        mock(:my_method)
      end
    end
    assert_failed(test_result)
    assert(test_result.failure_message_lines.any? do |line|
      line[/expected exactly once, invoked never\: #<Mock\:0x[0-9a-f]+>\.my_method\(any_parameters\)/]
    end)
  end

  def test_stub_built_with_single_symbol_argument
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        s = stub(:my_method)
        assert_nil s.my_method
      end
      expected_warning = 'Explicitly include `my_method` in Hash of stubbed methods vs return values, e.g. `stub(:my_method => nil)`.'
      assert_equal expected_warning, Mocha::Deprecation.messages.last
    end
    assert_passed(test_result)
  end

  def test_mock_built_with_first_argument_a_symbol_and_second_argument_a_hash
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        s = mock(:my_method, :another_method => 123)
        assert_nil s.my_method
      end
      expected_warning = 'In this case the 2nd argument for `mock(:#my_method, ...)` is ignored, but in the future a Hash of expected methods vs return values will be respected.'
      assert Mocha::Deprecation.messages.last(2).include?(expected_warning)
    end
    assert_passed(test_result)
  end

  def test_stub_built_with_first_argument_a_symbol_and_second_argument_a_hash
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        s = stub(:my_method, :another_method => 123)
        assert_nil s.my_method
      end
      expected_warning = 'In this case the 2nd argument for `stub(:#my_method, ...)` is ignored, but in the future a Hash of stubbed methods vs return values will be respected.'
      assert Mocha::Deprecation.messages.last(2).include?(expected_warning)
    end
    assert_passed(test_result)
  end

  def test_stub_everything_built_with_single_symbol_argument
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        s = stub_everything(:my_method)
        assert_nil s.my_method
      end
      expected_warning = 'Explicitly include `my_method` in Hash of stubbed methods vs return values, e.g. `stub_everything(:my_method => nil)`.'
      assert_equal expected_warning, Mocha::Deprecation.messages.last
    end
    assert_passed(test_result)
  end

  def test_stub_everything_built_with_first_argument_a_symbol_and_second_argument_a_hash
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        s = stub_everything(:my_method, :another_method => 123)
        assert_nil s.my_method
      end
      expected_warning = 'In this case the 2nd argument for `stub_everything(:#my_method, ...)` is ignored, but in the future a Hash of stubbed methods vs return values will be respected.' # rubocop:disable Metrics/LineLength
      assert Mocha::Deprecation.messages.last(2).include?(expected_warning)
    end
    assert_passed(test_result)
  end
end
