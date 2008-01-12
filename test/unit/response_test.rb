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
    response = Response.new(true, 'message', {}, :avs_result => { :code => 'A', :street_match => 'Y', :zip_match => 'N' })
    avs_result = response.avs_result
    assert_equal 'A', avs_result['code']
    assert_equal AVSResult.messages['A'], avs_result['message']
  end
  
  def test_cvv_result
    response = Response.new(true, 'message', {}, :cvv_result => 'M')
    cvv_result = response.cvv_result
    assert_equal 'M', cvv_result['code']
    assert_equal CVVResult.messages['M'], cvv_result['message']
  end
  
  def test_card_data
    response = Response.new(true, 'message', {}, :card_number => '5105105105105100')
    assert_equal 'master', response.card_data['type']
    assert_equal CreditCard.last_digits('5105105105105100'), response.card_data['number']
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
