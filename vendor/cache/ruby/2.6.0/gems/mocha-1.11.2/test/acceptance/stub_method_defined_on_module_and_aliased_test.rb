require File.expand_path('../acceptance_test_helper', __FILE__)

unless Mocha::PRE_RUBY_V19
  class StubMethodDefinedOnModuleAndAliasedTest < Mocha::TestCase
    include AcceptanceTest

    def setup
      setup_acceptance_test
    end

    def teardown
      teardown_acceptance_test
    end

    def test_stubbing_class_method_defined_by_aliasing_module_instance_method
      mod = Module.new do
        def module_instance_method
          'module-instance-method'
        end
      end

      klass = Class.new do
        extend mod
        class << self
          alias_method :aliased_module_instance_method, :module_instance_method
        end
      end

      assert_snapshot_unchanged(klass) do
        test_result = run_as_test do
          klass.stubs(:aliased_module_instance_method).returns('stubbed-aliased-module-instance-method')
          assert_equal 'stubbed-aliased-module-instance-method', klass.aliased_module_instance_method
        end
        assert_passed(test_result)
      end
    end
  end
end
