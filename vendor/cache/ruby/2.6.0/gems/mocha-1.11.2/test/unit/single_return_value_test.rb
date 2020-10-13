require File.expand_path('../../test_helper', __FILE__)

require 'mocha/invocation'
require 'mocha/single_return_value'

class SingleReturnValueTest < Mocha::TestCase
  include Mocha

  def new_invocation
    Invocation.new(:irrelevant, :irrelevant)
  end

  def test_should_return_value
    value = SingleReturnValue.new('value')
    assert_equal 'value', value.evaluate(new_invocation)
  end
end
