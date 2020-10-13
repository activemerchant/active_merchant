require File.expand_path('../../test_helper', __FILE__)
require 'method_definer'
require 'mocha/class_methods'
require 'mocha/mock'
require 'mocha/any_instance_method'

class AnyInstanceMethodTest < Mocha::TestCase
  include MethodDefiner
  include Mocha

  def class_with_method(method, result = nil)
    Class.new do
      extend ClassMethods
      define_method(method) { result } if method
    end
  end

  unless RUBY_V2_PLUS
    def test_should_hide_original_method
      klass = class_with_method(:method_x)
      method = AnyInstanceMethod.new(klass, :method_x)

      method.hide_original_method

      assert_equal false, klass.method_defined?(:method_x)
    end
  end

  def test_should_not_raise_error_hiding_method_that_isnt_defined
    klass = class_with_method(:irrelevant)
    method = AnyInstanceMethod.new(klass, :method_x)

    assert_nothing_raised { method.hide_original_method }
  end

  def test_should_define_a_new_method
    klass = class_with_method(:method_x)
    method = AnyInstanceMethod.new(klass, :method_x)
    mocha = build_mock
    mocha.expects(:method_x).with(:param1, :param2).returns(:result)
    any_instance = Object.new
    define_instance_method(any_instance, :mocha) { mocha }
    define_instance_method(klass, :any_instance) { any_instance }

    method.hide_original_method
    method.define_new_method

    instance = klass.new
    result = instance.method_x(:param1, :param2)

    assert_equal :result, result
    assert mocha.__verified__?
  end

  def test_should_include_the_filename_and_line_number_in_exceptions
    klass = class_with_method(:method_x)
    method = AnyInstanceMethod.new(klass, :method_x)
    mocha = build_mock
    mocha.stubs(:method_x).raises(Exception)
    any_instance = Object.new
    define_instance_method(any_instance, :mocha) { mocha }
    define_instance_method(klass, :any_instance) { any_instance }

    method.hide_original_method
    method.define_new_method

    expected_filename = 'stubbed_method.rb'
    expected_line_number = 61

    exception = assert_raises(Exception) { klass.new.method_x }
    matching_line = exception.backtrace.find do |line|
      filename, line_number, _context = line.split(':')
      filename.include?(expected_filename) && line_number.to_i == expected_line_number
    end

    assert_not_nil matching_line, "Expected to find #{expected_filename}:#{expected_line_number} in the backtrace:\n #{exception.backtrace.join("\n")}"
  end

  def test_should_restore_original_method
    klass = class_with_method(:method_x, :original_result)
    method = AnyInstanceMethod.new(klass, :method_x)

    method.hide_original_method
    method.define_new_method
    method.remove_new_method
    method.restore_original_method

    instance = klass.new
    assert instance.respond_to?(:method_x)
    assert_equal :original_result, instance.method_x
  end

  def test_should_not_restore_original_method_if_none_was_defined_in_first_place
    klass = class_with_method(:method_x, :new_result)
    method = AnyInstanceMethod.new(klass, :method_x)

    method.restore_original_method

    instance = klass.new
    assert_equal :new_result, instance.method_x
  end

  def test_should_call_remove_new_method
    klass = class_with_method(:method_x)
    any_instance = build_mock
    any_instance_mocha = build_mock
    any_instance.stubs(:mocha).returns(any_instance_mocha)
    define_instance_method(klass, :any_instance) { any_instance }
    method = AnyInstanceMethod.new(klass, :method_x)
    replace_instance_method(method, :restore_original_method) {}
    replace_instance_method(method, :reset_mocha) {}
    define_instance_accessor(method, :remove_called)
    replace_instance_method(method, :remove_new_method) { self.remove_called = true }

    method.unstub

    assert method.remove_called
  end

  def test_should_call_restore_original_method
    klass = class_with_method(:method_x)
    any_instance = build_mock
    any_instance_mocha = build_mock
    any_instance.stubs(:mocha).returns(any_instance_mocha)
    define_instance_method(klass, :any_instance) { any_instance }
    method = AnyInstanceMethod.new(klass, :method_x)
    replace_instance_method(method, :remove_new_method) {}
    replace_instance_method(method, :reset_mocha) {}
    define_instance_accessor(method, :restore_called)
    replace_instance_method(method, :restore_original_method) { self.restore_called = true }

    method.unstub

    assert method.restore_called
  end

  def test_should_call_mock_unstub
    klass = class_with_method(:method_x)

    method = AnyInstanceMethod.new(klass, :method_x)

    replace_instance_method(method, :remove_new_method) {}
    replace_instance_method(method, :restore_original_method) {}
    mocha = Class.new do
      class << self
        attr_accessor :unstub_method
      end
      def self.unstub(method)
        self.unstub_method = method
      end
    end
    define_instance_method(mocha, :any_expectations?) { true }
    replace_instance_method(method, :mock) { mocha }

    method.unstub

    assert_equal mocha.unstub_method, :method_x
  end

  def test_should_return_any_instance_mocha_for_stubbee
    mocha = Object.new
    any_instance = Object.new
    define_instance_method(any_instance, :mocha) { mocha }
    stubbee = class_with_method(:method_x)
    define_instance_method(stubbee, :any_instance) { any_instance }
    method = AnyInstanceMethod.new(stubbee, :method_name)
    assert_equal stubbee.any_instance.mocha, method.mock
  end

  private

  def build_mock
    Mock.new(nil)
  end
end
