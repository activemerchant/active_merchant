require 'test_helper'

class NmiVaultTest < Test::Unit::TestCase
  def setup
    @gateway = NmiVaultGateway.new(
                 :login => 'demo',
                 :password => 'password'
               )

    @credit_card = credit_card('4111111111111111')
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, '0af0df14241cff2db9d369339c34109a', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '2129769795', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, '0af0df14241cff2db9d369339c34109a', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, '0af0df14241cff2db9d369339c34109a', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '2129845466', response.authorization
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    assert response = @gateway.authorize(@amount, '0af0df14241cff2db9d369339c34109a', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, '2129845466', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '2129855547', response.authorization
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(101, '2129845466', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('2129845466', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '2129861829', response.authorization
    assert response.test?
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('212984546611111', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, '2129845466', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '2129868640', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(101, '2129845466', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '0839241a1321615a9f9e8ba8612012c9', response.authorization
    assert response.test?
  end

  def test_unsuccessful_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)

    assert response = @gateway.update('0839241a1321615a9f9e8ba8612012c9', @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '0839241a1321615a9f9e8ba8612012c9', response.authorization
    assert response.test?
  end

  def test_unsuccessful_update
    @gateway.expects(:ssl_post).returns(failed_update_response)

    assert response = @gateway.update('0839241a1321615a9f9e8ba8612012c9', @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)

    assert response = @gateway.unstore('0839241a1321615a9f9e8ba8612012c9')
    assert_instance_of Response, response
    assert_success response

    assert_equal '', response.authorization
    assert response.test?
  end

  def test_unsuccessful_unstore
    @gateway.expects(:ssl_post).returns(failed_unstore_response)

    assert response = @gateway.unstore('0839241a1321615a9f9e8ba8612012c9')
    assert_failure response
    assert response.test?
  end

  private

  def successful_store_response
    "response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=1&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0839241a1321615a9f9e8ba8612012c9"
  end

  def failed_store_response
    "response=3&responsetext=Required Field cc_number is Missing or Empty REFID:6558379&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=1&type=&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_update_response
    "response=1&responsetext=Customer Update Successful&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=1&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0839241a1321615a9f9e8ba8612012c9"
  end

  def failed_update_response
    "response=3&responsetext=Invalid Customer Vault Id REFID:6558346&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=1&type=&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0839241a1321615a9f9e8ba8612012c9"
  end

  def successful_unstore_response
    "response=1&responsetext=Customer Deleted&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def failed_unstore_response
    "response=3&responsetext=Invalid Customer Vault Id REFID:6558233&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0839241a1321615a9f9e8ba8612012c9"
  end

  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=2129769795&avsresponse=Y&cvvresponse=&orderid=1&type=sale&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0af0df14241cff2db9d369339c34109a"
  end

  def failed_purchase_response
    "response=2&responsetext=DECLINE&authcode=&transactionid=2129848313&avsresponse=Y&cvvresponse=&orderid=1&type=sale&response_code=200&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0af0df14241cff2db9d369339c34109a"
  end

  def successful_authorize_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=2129845466&avsresponse=Y&cvvresponse=&orderid=1&type=auth&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0af0df14241cff2db9d369339c34109a"
  end

  def failed_authorize_response
    "response=2&responsetext=DECLINE&authcode=&transactionid=2129847300&avsresponse=Y&cvvresponse=&orderid=1&type=auth&response_code=200&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id=0af0df14241cff2db9d369339c34109a"
  end

  def successful_capture_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=2129855547&avsresponse=&cvvresponse=&orderid=1&type=capture&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def failed_capture_response
    "response=3&responsetext=The specified amount of 1.01 exceeds the authorization amount of 1.00 REFID:6562928&authcode=&transactionid=2129859170&avsresponse=&cvvresponse=&orderid=1&type=capture&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_void_response
    "response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=2129861829&avsresponse=&cvvresponse=&orderid=1&type=void&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def failed_void_response
    "response=3&responsetext=Invalid Transaction ID specified REFID:6563022&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=void&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def successful_refund_response
    "response=1&responsetext=SUCCESS&authcode=&transactionid=2129868640&avsresponse=&cvvresponse=&orderid=1&type=refund&response_code=100&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end

  def failed_refund_response
    "response=3&responsetext=Refund amount may not exceed the transaction balance REFID:6563114&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=300&merchant_defined_field_6=&merchant_defined_field_7=&customer_vault_id="
  end
end
