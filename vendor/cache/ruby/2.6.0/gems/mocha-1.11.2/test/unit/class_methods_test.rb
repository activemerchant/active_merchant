require File.expand_path('../../test_helper', __FILE__)
require 'mocha/class_methods'
require 'mocha/object_methods'
require 'mocha/mockery'
require 'mocha/names'

class ClassMethodsTest < Mocha::TestCase
  def setup
    Mocha::Mockery.setup
    @klass = Class.new.extend(Mocha::ClassMethods, Mocha::ObjectMethods)
  end

  def teardown
    Mocha::Mockery.teardown
  end

  def test_should_build_any_instance_object
    any_instance = @klass.any_instance
    assert_not_nil any_instance
    assert any_instance.is_a?(Mocha::ClassMethods::AnyInstance)
  end

  def test_should_return_same_any_instance_object
    any_instance1 = @klass.any_instance
    any_instance2 = @klass.any_instance
    assert_equal any_instance1, any_instance2
  end

  def test_any_instance_should_build_mocha_referring_to_klass
    mocha = @klass.any_instance.mocha
    assert_not_nil mocha
    assert mocha.is_a?(Mocha::Mock)
    expected_name = Mocha::ImpersonatingAnyInstanceName.new(@klass).mocha_inspect
    assert_equal expected_name, mocha.mocha_inspect
  end

  def test_any_instance_should_not_build_mocha_if_instantiate_is_false
    assert_nil @klass.any_instance.mocha(false)
  end

  def test_any_instance_should_reuse_existing_mocha
    mocha1 = @klass.any_instance.mocha
    mocha2 = @klass.any_instance.mocha
    assert_equal mocha1, mocha2
  end

  def test_any_instance_should_reuse_existing_mocha_even_if_instantiate_is_false
    mocha1 = @klass.any_instance.mocha
    mocha2 = @klass.any_instance.mocha(false)
    assert_equal mocha1, mocha2
  end

  def test_should_use_stubba_class_method_for_class
    assert_equal Mocha::InstanceMethod, @klass.stubba_method
  end

  def test_should_use_stubba_class_method_for_any_instance
    assert_equal Mocha::AnyInstanceMethod, @klass.any_instance.stubba_method
  end

  def test_should_stub_self_for_class
    assert_equal @klass, @klass.stubba_object
  end

  def test_should_stub_relevant_class_for_any_instance
    any_instance = @klass.any_instance
    assert_equal @klass, any_instance.stubba_object
  end
end
