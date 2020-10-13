require File.expand_path('../acceptance_test_helper', __FILE__)
require 'mocha/configuration'
require 'mocha/deprecation'
require 'deprecation_disabler'

class MockTest < Mocha::TestCase
  include AcceptanceTest
  include Mocha

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_should_build_mock_and_explicitly_add_an_expectation_which_is_satisfied
    test_result = run_as_test do
      foo = mock
      foo.expects(:bar)
      foo.bar
    end
    assert_passed(test_result)
  end

  def test_should_build_mock_and_explicitly_add_an_expectation_which_is_not_satisfied
    test_result = run_as_test do
      foo = mock
      foo.expects(:bar)
    end
    assert_failed(test_result)
  end

  def test_should_build_string_named_mock_and_explicitly_add_an_expectation_which_is_satisfied
    test_result = run_as_test do
      foo = mock('foo')
      foo.expects(:bar)
      foo.bar
    end
    assert_passed(test_result)
  end

  def test_should_build_symbol_named_mock_and_explicitly_add_an_expectation_which_is_satisfied
    test_result = run_as_test do
      Mocha::Configuration.override(:reinstate_undocumented_behaviour_from_v1_9 => false) do
        DeprecationDisabler.disable_deprecations do
          foo = mock(:foo)
          foo.expects(:bar)
          foo.bar
        end
      end
    end
    assert_passed(test_result)
  end

  def test_should_build_string_named_mock_and_explicitly_add_an_expectation_which_is_not_satisfied
    test_result = run_as_test do
      foo = mock('foo')
      foo.expects(:bar)
    end
    assert_failed(test_result)
  end

  def test_should_build_symbol_named_mock_and_explicitly_add_an_expectation_which_is_not_satisfied
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        foo = mock(:foo)
        foo.expects(:bar)
      end
    end
    assert_failed(test_result)
  end

  def test_should_build_mock_incorporating_two_expectations_which_are_satisifed
    test_result = run_as_test do
      foo = mock(:bar => 'bar', :baz => 'baz')
      foo.bar
      foo.baz
    end
    assert_passed(test_result)
  end

  def test_should_build_mock_incorporating_two_expectations_the_first_of_which_is_not_satisifed
    test_result = run_as_test do
      foo = mock(:bar => 'bar', :baz => 'baz')
      foo.baz
    end
    assert_failed(test_result)
  end

  def test_should_build_mock_incorporating_two_expectations_the_second_of_which_is_not_satisifed
    test_result = run_as_test do
      foo = mock(:bar => 'bar', :baz => 'baz')
      foo.bar
    end
    assert_failed(test_result)
  end

  def test_should_build_string_named_mock_incorporating_two_expectations_which_are_satisifed
    test_result = run_as_test do
      foo = mock('foo', :bar => 'bar', :baz => 'baz')
      foo.bar
      foo.baz
    end
    assert_passed(test_result)
  end

  def test_should_build_symbol_named_mock_incorporating_two_expectations_which_are_satisifed
    test_result = run_as_test do
      Mocha::Configuration.override(:reinstate_undocumented_behaviour_from_v1_9 => false) do
        DeprecationDisabler.disable_deprecations do
          foo = mock(:foo, :bar => 'bar', :baz => 'baz')
          foo.bar
          foo.baz
        end
      end
    end
    assert_passed(test_result)
  end

  def test_should_build_string_named_mock_incorporating_two_expectations_the_first_of_which_is_not_satisifed
    test_result = run_as_test do
      foo = mock('foo', :bar => 'bar', :baz => 'baz')
      foo.baz
    end
    assert_failed(test_result)
  end

  def test_should_build_symbol_named_mock_incorporating_two_expectations_the_first_of_which_is_not_satisifed
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        foo = mock(:foo, :bar => 'bar', :baz => 'baz')
        foo.baz
      end
    end
    assert_failed(test_result)
  end

  def test_should_build_string_named_mock_incorporating_two_expectations_the_second_of_which_is_not_satisifed
    test_result = run_as_test do
      foo = mock('foo', :bar => 'bar', :baz => 'baz')
      foo.bar
    end
    assert_failed(test_result)
  end

  def test_should_build_symbol_named_mock_incorporating_two_expectations_the_second_of_which_is_not_satisifed
    test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        foo = mock(:foo, :bar => 'bar', :baz => 'baz')
        foo.bar
      end
    end
    assert_failed(test_result)
  end

  class Foo
    class << self
      attr_accessor :logger
    end

    def use_the_mock
      self.class.logger.log('Foo was here')
    end
  end

  # rubocop:disable Metrics/AbcSize
  def test_should_display_deprecation_warning_if_mock_receives_invocations_in_another_test
    use_mock_test_result = run_as_test do
      Foo.logger = mock('Logger')
      Foo.logger.expects(:log).with('Foo was here')
      Foo.new.use_the_mock
    end
    assert_passed(use_mock_test_result)

    reuse_mock_test_result = run_as_test do
      DeprecationDisabler.disable_deprecations do
        Foo.logger.expects(:log).with('Foo was here')
        Foo.new.use_the_mock
      end
    end
    assert_passed(reuse_mock_test_result)
    assert message = Deprecation.messages.last
    assert message.include?('#<Mock:Logger> was instantiated in one test but it is receiving invocations within another test.')
    assert message.include?('This can lead to unintended interactions between tests and hence unexpected test failures.')
    assert message.include?('Ensure that every test correctly cleans up any state that it introduces.')
    assert message.include?('A Mocha::StubbingError will be raised in this scenario in the future.')
  end
  # rubocop:enable Metrics/AbcSize
end
