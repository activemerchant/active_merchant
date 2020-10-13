require File.expand_path('../acceptance_test_helper', __FILE__)
require 'mocha/not_initialized_error'

class PreventUseOfMochaOutsideTestTest < Mocha::TestCase
  include AcceptanceTest

  def setup
    setup_acceptance_test
    mocha_teardown
  end

  def teardown
    teardown_acceptance_test
  end

  def test_should_raise_exception_when_mock_called_outside_test
    assert_raises(Mocha::NotInitializedError) { mock('object') }
  end

  def test_should_raise_exception_when_stub_called_outside_test
    assert_raises(Mocha::NotInitializedError) { stub('object') }
  end

  def test_should_raise_exception_when_stub_everything_called_outside_test
    assert_raises(Mocha::NotInitializedError) { stub_everything('object') }
  end

  def test_should_raise_exception_when_states_called_outside_test
    assert_raises(Mocha::NotInitializedError) { states('state-machine') }
  end

  def test_should_raise_exception_when_expects_called_on_instance_outside_test
    instance = Class.new.new
    assert_raises(Mocha::NotInitializedError) { instance.expects(:expected_method) }
  end

  def test_should_raise_exception_when_expects_called_on_class_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.expects(:expected_method) }
  end

  def test_should_raise_exception_when_expects_called_on_any_instance_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.any_instance.expects(:expected_method) }
  end

  def test_should_raise_exception_when_stubs_called_on_instance_outside_test
    instance = Class.new.new
    assert_raises(Mocha::NotInitializedError) { instance.stubs(:expected_method) }
  end

  def test_should_raise_exception_when_stubs_called_on_class_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.stubs(:expected_method) }
  end

  def test_should_raise_exception_when_stubs_called_on_any_instance_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.any_instance.stubs(:expected_method) }
  end

  def test_should_raise_exception_when_unstub_called_on_instance_outside_test
    instance = Class.new.new
    assert_raises(Mocha::NotInitializedError) { instance.unstub(:expected_method) }
  end

  def test_should_raise_exception_when_unstub_called_on_class_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.unstub(:expected_method) }
  end

  def test_should_raise_exception_when_unstub_called_on_any_instance_outside_test
    klass = Class.new
    assert_raises(Mocha::NotInitializedError) { klass.any_instance.unstub(:expected_method) }
  end
end
