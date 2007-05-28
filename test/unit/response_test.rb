require File.dirname(__FILE__) + '/../test_helper'

class ResponseTest < Test::Unit::TestCase
  def test_response_success
    assert Response.new(true, 'message', :param => 'value').success?
    assert !Response.new(false, 'message', :param => 'value').success?
  end
  
  def test_get_params
    response = Response.new(true, 'message', :param => 'value')
    
    assert_equal ['param'], response.params.keys    
  end
end
