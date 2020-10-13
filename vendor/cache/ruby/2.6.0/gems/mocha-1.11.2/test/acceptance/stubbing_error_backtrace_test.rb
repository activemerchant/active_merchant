require File.expand_path('../acceptance_test_helper', __FILE__)
require 'execution_point'

class StubbingErrorBacktraceTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  # rubocop:disable Style/Semicolon
  def test_should_display_backtrace_indicating_line_number_where_attempt_to_stub_non_existent_method_was_made
    execution_point = nil
    object = Object.new
    Mocha.configure { |c| c.stubbing_non_existent_method = :prevent }
    test_result = run_as_test do
      execution_point = ExecutionPoint.current; object.stubs(:non_existent_method)
    end
    assert_equal 1, test_result.error_count
    assert_equal execution_point, ExecutionPoint.new(test_result.errors[0].exception.backtrace)
  end

  def test_should_display_backtrace_indicating_line_number_where_attempt_to_stub_non_public_method_was_made
    execution_point = nil
    object = Class.new do
      def non_public_method; end
      private :non_public_method
    end.new
    Mocha.configure { |c| c.stubbing_non_public_method = :prevent }
    test_result = run_as_test do
      execution_point = ExecutionPoint.current; object.stubs(:non_public_method)
    end
    assert_equal 1, test_result.error_count
    assert_equal execution_point, ExecutionPoint.new(test_result.errors[0].exception.backtrace)
  end

  def test_should_display_backtrace_indicating_line_number_where_attempt_to_stub_method_on_non_mock_object_was_made
    execution_point = nil
    object = Object.new
    Mocha.configure { |c| c.stubbing_method_on_non_mock_object = :prevent }
    test_result = run_as_test do
      execution_point = ExecutionPoint.current; object.stubs(:any_method)
    end
    assert_equal 1, test_result.error_count
    assert_equal execution_point, ExecutionPoint.new(test_result.errors[0].exception.backtrace)
  end

  def test_should_display_backtrace_indicating_line_number_where_method_was_unnecessarily_stubbed
    execution_point = nil
    object = Object.new
    Mocha.configure { |c| c.stubbing_method_unnecessarily = :prevent }
    test_result = run_as_test do
      execution_point = ExecutionPoint.current; object.stubs(:unused_method)
    end
    assert_equal 1, test_result.error_count
    assert_equal execution_point, ExecutionPoint.new(test_result.errors[0].exception.backtrace)
  end
  # rubocop:enable Style/Semicolon
end
