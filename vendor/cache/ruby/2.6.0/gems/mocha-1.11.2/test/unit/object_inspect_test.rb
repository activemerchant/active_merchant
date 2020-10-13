require File.expand_path('../../test_helper', __FILE__)
require 'mocha/ruby_version'
require 'mocha/inspect'
require 'method_definer'

class ObjectInspectTest < Mocha::TestCase
  include MethodDefiner

  def test_should_return_default_string_representation_of_object_not_including_instance_variables
    object = Object.new
    class << object
      attr_accessor :attribute
    end
    object.attribute = 'instance_variable'
    assert_match Regexp.new('^#<Object:0x[0-9A-Fa-f]{1,8}.*>$'), object.mocha_inspect
    assert_no_match(/instance_variable/, object.mocha_inspect)
  end

  def test_should_return_customized_string_representation_of_object
    object = Object.new
    class << object
      define_method(:inspect) { 'custom_inspect' }
    end
    assert_equal 'custom_inspect', object.mocha_inspect
  end

  def test_should_use_underscored_id_instead_of_object_id_or_id_so_that_they_can_be_stubbed
    calls = []
    object = Object.new
    if Mocha::PRE_RUBY_V19
      replace_instance_method(object, :id) do
        calls << :id
        return 1
      end
    end
    replace_instance_method(object, :object_id) do
      calls << :object_id
      return 1
    end
    replace_instance_method(object, :__id__) do
      calls << :__id__
      return 1
    end
    replace_instance_method(object, :inspect) { 'object-description' }

    object.mocha_inspect

    assert_equal [:__id__], calls.uniq
  end

  def test_should_not_call_object_instance_format_method
    object = Object.new
    class << object
      def format(*)
        'internal_format'
      end
    end
    assert_no_match(/internal_format/, object.mocha_inspect)
  end
end
