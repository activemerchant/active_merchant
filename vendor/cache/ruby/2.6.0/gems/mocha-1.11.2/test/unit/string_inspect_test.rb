require File.expand_path('../../test_helper', __FILE__)
require 'mocha/inspect'

class StringInspectTest < Mocha::TestCase
  def test_should_use_default_inspect_method
    string = 'my_string'
    assert_equal %("my_string"), string.mocha_inspect
  end
end
