require File.expand_path('../../test_helper', __FILE__)
require 'mocha/object_methods'

class ModuleMethodsTest < Mocha::TestCase
  def setup
    @module = Module.new.extend(Mocha::ObjectMethods)
  end

  def test_should_use_stubba_module_method_for_module
    assert_equal Mocha::InstanceMethod, @module.stubba_method
  end

  def test_should_stub_self_for_module
    assert_equal @module, @module.stubba_object
  end
end
