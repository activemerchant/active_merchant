require File.expand_path('../acceptance_test_helper', __FILE__)

class StubInstanceMethodDefinedOnKernelModuleTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
  end

  def teardown
    teardown_acceptance_test
  end

  def test_should_stub_public_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      public :my_instance_method
    end
    instance = Class.new.new
    assert_snapshot_unchanged(instance) do
      test_result = run_as_test do
        instance.stubs(:my_instance_method).returns(:new_return_value)
        assert_equal :new_return_value, instance.my_instance_method
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, instance.my_instance_method
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end

  def test_should_stub_protected_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      protected :my_instance_method
    end
    instance = Class.new.new
    assert_snapshot_unchanged(instance) do
      test_result = run_as_test do
        instance.stubs(:my_instance_method).returns(:new_return_value)
        assert_equal :new_return_value, instance.send(:my_instance_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, instance.send(:my_instance_method)
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end

  def test_should_stub_private_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      private :my_instance_method
    end
    instance = Class.new.new
    assert_snapshot_unchanged(instance) do
      test_result = run_as_test do
        instance.stubs(:my_instance_method).returns(:new_return_value)
        assert_equal :new_return_value, instance.send(:my_instance_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, instance.send(:my_instance_method)
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end

  def test_should_stub_public_module_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      public :my_instance_method
    end
    mod = Module.new
    assert_snapshot_unchanged(mod) do
      test_result = run_as_test do
        mod.stubs(:my_instance_method).returns(:new_return_value)
        assert_method_visibility mod, :my_instance_method, :public
        assert_equal :new_return_value, mod.my_instance_method
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, mod.my_instance_method
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end

  def test_should_stub_protected_module_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      protected :my_instance_method
    end
    mod = Module.new
    assert_snapshot_unchanged(mod) do
      test_result = run_as_test do
        mod.stubs(:my_instance_method).returns(:new_return_value)
        assert_method_visibility mod, :my_instance_method, :protected
        assert_equal :new_return_value, mod.send(:my_instance_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, mod.send(:my_instance_method)
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end

  def test_should_stub_private_module_method_and_leave_it_unchanged_after_test
    Kernel.module_eval do
      def my_instance_method
        :original_return_value
      end
      private :my_instance_method
    end
    mod = Module.new
    assert_snapshot_unchanged(mod) do
      test_result = run_as_test do
        mod.stubs(:my_instance_method).returns(:new_return_value)
        assert_method_visibility mod, :my_instance_method, :private
        assert_equal :new_return_value, mod.send(:my_instance_method)
      end
      assert_passed(test_result)
    end
    assert_equal :original_return_value, mod.send(:my_instance_method)
  ensure
    Kernel.module_eval { remove_method :my_instance_method }
  end
end
