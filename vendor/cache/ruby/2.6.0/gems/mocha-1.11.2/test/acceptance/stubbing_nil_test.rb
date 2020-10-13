require File.expand_path('../acceptance_test_helper', __FILE__)
require 'mocha/configuration'

class StubbingNilTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  if RUBY_VERSION < '2.2.0'
    def test_should_allow_stubbing_method_on_nil
      Mocha.configure { |c| c.stubbing_method_on_nil = :allow }
      test_result = run_as_test do
        nil.stubs(:stubbed_method)
      end
      assert_passed(test_result)
      assert !@logger.warnings.include?('stubbing method on nil: nil.stubbed_method')
    end

    def test_should_warn_on_stubbing_method_on_nil
      Mocha.configure { |c| c.stubbing_method_on_nil = :warn }
      test_result = run_as_test do
        nil.stubs(:stubbed_method)
      end
      assert_passed(test_result)
      assert @logger.warnings.include?('stubbing method on nil: nil.stubbed_method')
    end

    def test_should_prevent_stubbing_method_on_nil
      Mocha.configure { |c| c.stubbing_method_on_nil = :prevent }
      test_result = run_as_test do
        nil.stubs(:stubbed_method)
      end
      assert_failed(test_result)
      assert test_result.error_messages.include?('Mocha::StubbingError: stubbing method on nil: nil.stubbed_method')
    end

    def test_should_default_to_prevent_stubbing_method_on_non_mock_object
      test_result = run_as_test do
        nil.stubs(:stubbed_method)
      end
      assert_failed(test_result)
      assert test_result.error_messages.include?('Mocha::StubbingError: stubbing method on nil: nil.stubbed_method')
    end

    def test_should_allow_stubbing_method_on_non_nil_object
      Mocha.configure { |c| c.stubbing_method_on_nil = :prevent }
      object = Object.new
      test_result = run_as_test do
        object.stubs(:stubbed_method)
      end
      assert_passed(test_result)
    end
  end
end
