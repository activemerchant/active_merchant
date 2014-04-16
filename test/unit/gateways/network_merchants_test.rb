require 'test_helper'

class NetworkMerchantsTest < Test::Unit::TestCase
  def setup
    @gateway = NetworkMerchantsGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1869031575', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_check_purchase)

    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal response.params['transactionid'], response.authorization
  end

  def test_purchase_and_store
    @gateway.expects(:ssl_post).returns(successful_purchase_and_store)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:store => true))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal "1378262091", response.params['customer_vault_id']
  end

  def test_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize)

    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
  end

  def test_capture
    @gateway.expects(:ssl_post).returns(successful_capture)

    amount = @amount
    assert auth = @gateway.capture(amount, '1869041506', @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture)

    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert response.message.include?('Invalid Transaction ID / Object ID specified')
  end

  def test_void
    @gateway.expects(:ssl_post).returns(successful_void)

    assert response = @gateway.void('1869041506', @options)
    assert_success response
    assert_equal "Transaction Void Successful", response.message
  end

  def test_refund
    @gateway.expects(:ssl_post).returns(successful_refund)

    assert response = @gateway.refund(50, "1869041506")
    assert_success response
    assert_equal "SUCCESS", response.message
    assert_equal "1869043195", response.authorization
  end

  def test_store
    @gateway.expects(:ssl_post).returns(successful_store)

    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal '1200085822', store.authorization
    assert_equal '1200085822', store.params['customer_vault_id']
  end

  def test_store_check
    @gateway.expects(:ssl_post).returns(successful_store)

    assert store = @gateway.store(@check, @options)
    assert_success store
    assert_equal '1200085822', store.authorization
    assert_equal '1200085822', store.params['customer_vault_id']
  end

  def test_store_failure
    @gateway.expects(:ssl_post).returns(failed_store)

    @credit_card.number = "123"
    assert store = @gateway.store(@creditcard, @options)
    assert_failure store
    assert store.message.include?('Billing Information missing')
    assert_nil store.authorization
    assert_equal '', store.params['customer_vault_id']
  end

  def test_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore)

    assert unstore = @gateway.unstore('1200085822')
    assert_success unstore
    assert_equal "Customer Deleted", unstore.message
  end

  def test_purchase_on_stored_card
    @gateway.expects(:ssl_post).returns(successful_purchase_on_stored_card)

    assert purchase = @gateway.purchase(@amount, 1200085822, @options)
    assert_success purchase
    assert_equal "SUCCESS", purchase.message
    assert_equal '1869047279', purchase.authorization
  end

  def test_invalid_login
    gateway = NetworkMerchantsGateway.new(:login => '', :password => '')
    gateway.expects(:ssl_post).returns(failed_login)
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Username', response.message
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869031575&avsresponse=N&cvvresponse=N&orderid=1&type=auth&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "response=2&responsetext=DECLINE&authcode=&transactionid=1869031793&avsresponse=N&cvvresponse=N&orderid=1&type=sale&response_code=200&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_check_purchase
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869039732&avsresponse=&cvvresponse=&orderid=1&type=sale&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_purchase_and_store
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869036881&avsresponse=N&cvvresponse=N&orderid=1&type=sale&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=1378262091"
  end

  def successful_authorize
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869041506&avsresponse=N&cvvresponse=N&orderid=1&type=auth&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_capture
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869041506&avsresponse=&cvvresponse=&orderid=1&type=capture&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def failed_capture
    "response=3&responsetext=Invalid Transaction ID / Object ID specified:  REFID:342421573&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=capture&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_void
    "response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=1869042801&avsresponse=&cvvresponse=&orderid=1&type=void&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_refund
    "response=1&responsetext=SUCCESS&authcode=&transactionid=1869043195&avsresponse=&cvvresponse=&orderid=1&type=refund&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_store
    "response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=1200085822"
  end

  def failed_store
    "response=3&responsetext=Billing Information missing REFID:342424380&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_unstore
    "response=1&responsetext=Customer Deleted&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_purchase_on_stored_card
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=1869047279&avsresponse=N&cvvresponse=&orderid=1&type=sale&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=1138093627"
  end

  def failed_login
    "response=3&responsetext=Invalid Username&authcode=&transactionid=0&avsresponse=&cvvresponse=&orderid=1&type=sale&response_code=300"
  end
end
