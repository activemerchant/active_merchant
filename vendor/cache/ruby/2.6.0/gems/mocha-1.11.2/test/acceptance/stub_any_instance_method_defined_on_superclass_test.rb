require File.expand_path('../acceptance_test_helper', __FILE__)

class StubAnyInstanceMethodDefinedOnSuperclassTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_should_stub_method_and_leave_it_unchanged_after_test
    superklass = Class.new do
      def my_superclass_method
        :original_return_value
      end
      public :my_superclass_method
    end
    klass = Class.new(superklass)
    instance = klass.new
    assert_snapshot_unchanged(instance) do
      test_result = run_as_test do
        superklass.any_instance.stubs(:my_superclass_method).returns(:new_return_value)
        assert_equal :new_return_value, instance.my_superclass_method
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, instance.my_superclass_method
  end

  def test_expect_method_on_any_instance_of_superclass_even_if_preceded_by_test_expecting_method_on_any_instance_of_subclass
    superklass = Class.new do
      def self.inspect
        'superklass'
      end

      def my_instance_method; end
    end
    klass = Class.new(superklass) do
      def self.inspect
        'klass'
      end

      def my_instance_method; end
    end
    test_result = run_as_tests(
      :test_1 => lambda {
        klass.any_instance.expects(:my_instance_method)
        klass.new.my_instance_method
      },
      :test_2 => lambda {
        superklass.any_instance.expects(:my_instance_method)
      }
    )
    assert_failed(test_result)
    assert_equal [
      'not all expectations were satisfied',
      'unsatisfied expectations:',
      '- expected exactly once, invoked never: #<AnyInstance:superklass>.my_instance_method(any_parameters)'
    ], test_result.failure_message_lines
  end
end
