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
  
  def test_avs_result
    response = Response.new(true, 'message', {}, :avs_code => 'A')
    assert_equal 'A', response.avs_result['code']
  end
  
  def test_cvv_result
    response = Response.new(true, 'message', {}, :cvv_code => 'M')
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_card_data
    response = Response.new(true, 'message', {}, :card_number => '5105105105105100')
    assert_equal 'master', response.card_data['type']
    assert_equal 'XXXX-XXXX-XXXX-5100', response.card_data['number']
  end
  
  def test_empty_card_data
    response = Response.new(true, 'message', {}, :card_number => nil)
    assert_nil response.card_data['type']
    assert_nil response.card_data['number']
  end
  
  def test_blank_card_data
    response = Response.new(true, 'message', {}, :card_number => '')
    assert_nil response.card_data['type']
    assert_nil response.card_data['number']
  end
end
