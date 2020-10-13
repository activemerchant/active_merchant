require File.expand_path('../acceptance_test_helper', __FILE__)

class StubClassMethodDefinedOnClassTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  # rubocop:disable Lint/DuplicateMethods
  def test_should_stub_public_method_and_leave_it_unchanged_after_test
    klass = Class.new do
      class << self
        def my_class_method
          :original_return_value
        end
        public :my_class_method
        def self.public(*args); end
      end
    end
    assert_snapshot_unchanged(klass) do
      test_result = run_as_test do
        klass.stubs(:my_class_method).returns(:new_return_value)
        assert_method_visibility klass, :my_class_method, :public
        assert_equal :new_return_value, klass.my_class_method
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, klass.my_class_method
  end

  def test_should_stub_protected_method_and_leave_it_unchanged_after_test
    klass = Class.new do
      class << self
        def my_class_method
          :original_return_value
        end
        protected :my_class_method
        def self.protected(*args); end
      end
    end
    assert_snapshot_unchanged(klass) do
      test_result = run_as_test do
        klass.stubs(:my_class_method).returns(:new_return_value)
        assert_method_visibility klass, :my_class_method, :protected
        assert_equal :new_return_value, klass.send(:my_class_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, klass.send(:my_class_method)
  end

  def test_should_stub_private_method_and_leave_it_unchanged_after_test
    klass = Class.new do
      class << self
        def my_class_method
          :original_return_value
        end
        private :my_class_method
        def self.private(*args); end
      end
    end
    assert_snapshot_unchanged(klass) do
      test_result = run_as_test do
        klass.stubs(:my_class_method).returns(:new_return_value)
        assert_method_visibility klass, :my_class_method, :private
        assert_equal :new_return_value, klass.send(:my_class_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, klass.send(:my_class_method)
  end
  # rubocop:enable Lint/DuplicateMethods
end
