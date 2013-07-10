require 'test_helper'

class EvoCaTest < Test::Unit::TestCase
  def setup
    @gateway = EvoCaGateway.new(:username => 'demo', :password => 'password')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :tracking_number => '123456789-0',
      :shipping_carrier => 'fedex',
      :email => 'evo@example.com',
      :ip => '127.0.0.1'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1812592532', response.authorization
    assert_equal '123456', response.params['authcode']
    assert_equal EvoCaGateway::MESSAGES[100], response.message
    assert_equal 'SUCCESS', response.params['responsetext']
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1812622314', response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_success response
    assert_equal '1812622314', response.authorization
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_check_purchase_response)
    assert response = @gateway.purchase(@amount, check, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1813337957', response.authorization
    assert_equal '123456', response.params['authcode']
    assert_equal EvoCaGateway::MESSAGES[100], response.message
    assert_equal 'SUCCESS', response.params['responsetext']
  end

  def test_failed_check_purchase
    @gateway.expects(:ssl_post).returns(failed_check_purchase_response)
    assert response = @gateway.purchase(@amount, check, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.authorization.empty?
    assert response.params['authcode'].empty?
    assert_equal EvoCaGateway::MESSAGES[300], response.message
    assert_equal 'Invalid ABA number REFID:340098220', response.params['responsetext']
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void('1812629062')
    assert_success response
    assert_equal '1812629062', response.authorization
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)
    assert response = @gateway.update('1812639342', :tracking_number => '1234', :shipping_carrier => 'fedex')
    assert_success response
    assert_equal '1812639342', response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.credit(200, @credit_card)
    assert_success response
    assert_equal '1813383422', response.authorization
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, :address => {:address1 => '123 Main Street', :country => 'CA', :state => 'BC'} )
    assert_equal %w{address1 address2 city company country firstname lastname phone state zip}, result.stringify_keys.keys.sort
    assert_equal 'BC', result[:state]
    assert_equal '123 Main Street', result[:address1]
    assert_equal 'CA', result[:country]
  end

  def test_add_shipping_address
    result = {}

    @gateway.send(:add_address, result, :shipping_address => {:address1 => '123 Main Street', :country => 'CA', :state => 'BC'} )
    assert_equal %w{shipping_address1 shipping_address2 shipping_city shipping_company shipping_country shipping_firstname shipping_lastname shipping_state shipping_zip}, result.stringify_keys.keys.sort
    assert_equal 'BC', result[:shipping_state]
    assert_equal '123 Main Street', result[:shipping_address1]
    assert_equal 'CA', result[:shipping_country]
  end

  def test_add_order
    result = {}

    @gateway.send(:add_order, result, @options)
    assert_equal %w{orderid shipping_carrier tracking_number}, result.stringify_keys.keys.sort
    assert_equal '1', result[:orderid]
    assert_equal 'fedex', result[:shipping_carrier]
    assert_equal '123456789-0', result[:tracking_number]
  end

  def test_add_credit_card
    result = {}

    @gateway.send(:add_paymentmethod, result, @credit_card)
    assert_equal %w{ccexp ccnumber cvv payment}, result.stringify_keys.keys.sort
    assert_equal 'creditcard', result[:payment]
    assert_equal @credit_card.number, result[:ccnumber]
  end

  def test_add_check
    result = {}

    @gateway.send(:add_paymentmethod, result, check)
    assert_equal %w{account_holder_type account_type checkaba checkaccount checkname payment}, result.stringify_keys.keys.sort
    assert_equal 'check', result[:payment]
    assert_equal check.routing_number, result[:checkaba]
  end

  def test_add_customer_data
    result = {}

    @gateway.send(:add_customer_data, result, @options)
    assert_equal %w{email ipaddress}, result.stringify_keys.keys.sort
    assert_equal 'evo@example.com', result[:email]
    assert_equal '127.0.0.1', result[:ipaddress]
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'N', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'N', response.cvv_result['code']
  end

  private

  def successful_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=1812592532&avsresponse=N&cvvresponse=N&orderid=1&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def failed_purchase_response
    'response=2&responsetext=DECLINE&authcode=&transactionid=1812592725&avsresponse=N&cvvresponse=N&orderid=1&type=&response_code=200&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_check_purchase_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=1813337957&avsresponse=&cvvresponse=&orderid=&type=sale&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def failed_check_purchase_response
    'response=3&responsetext=Invalid ABA number REFID:340098220&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=sale&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_authorize_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=1812622314&avsresponse=&cvvresponse=&orderid=&type=auth&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_capture_response
    'response=1&responsetext=SUCCESS&authcode=123456&transactionid=1812622314&avsresponse=&cvvresponse=&orderid=1&type=capture&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_void_response
    'response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=1812629062&avsresponse=&cvvresponse=&orderid=&type=void&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_refund_response
    'response=1&responsetext=SUCCESS&authcode=&transactionid=1812631331&avsresponse=&cvvresponse=&orderid=&type=credit&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_update_response
    'response=1&responsetext=&authcode=123456&transactionid=1812639342&avsresponse=&cvvresponse=&orderid=99999&type=update&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end

  def successful_credit_response
    'response=1&responsetext=SUCCESS&authcode=&transactionid=1813383422&avsresponse=&cvvresponse=&orderid=99999&type=credit&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id='
  end
end
