require File.expand_path('../acceptance_test_helper', __FILE__)

class Issue65Test < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_expectations_on_class_methods_on_same_class_should_be_verified_in_consecutive_tests
    klass = Class.new do
      def self.foo; end

      def self.bar; end
    end
    test1 = run_as_test do
      klass.expects(:foo)
      klass.foo
    end
    assert_passed(test1)
    test2 = run_as_test do
      klass.expects(:bar)
    end
    assert_failed(test2)
  end

  def test_expectations_on_any_instance_methods_on_same_class_should_be_verified_in_consecutive_tests
    klass = Class.new do
      def foo; end

      def bar; end
    end
    test1 = run_as_test do
      klass.any_instance.expects(:foo)
      klass.new.foo
    end
    assert_passed(test1)
    test2 = run_as_test do
      klass.any_instance.expects(:bar)
    end
    assert_failed(test2)
  end

  def test_expectations_on_instance_methods_on_same_object_should_be_verified_in_consecutive_tests
    instance = Class.new do
      def foo; end

      def bar; end
    end.new
    test1 = run_as_test do
      instance.expects(:foo)
      instance.foo
    end
    assert_passed(test1)
    test2 = run_as_test do
      instance.expects(:bar)
    end
    assert_failed(test2)
  end
end
