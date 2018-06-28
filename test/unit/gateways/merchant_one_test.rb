require 'test_helper'

class MerchantOneTest < Test::Unit::TestCase

  def setup
    @gateway = MerchantOneGateway.new(fixtures(:merchant_one))
    @credit_card = credit_card
    @amount = 1000
    @options = {
      :order_id => '1',
      :description => 'Store Purchase',
      :billing_address => {
        :name =>'Jim Smith',
        :address1 =>'1234 My Street',
        :address2 =>'Apt 1',
        :city =>'Tampa',
        :state =>'FL',
        :zip =>'33603',
        :country =>'US',
        :phone =>'(813)421-4331'
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal "281719471", response.authorization
    assert response.test?, response.test.to_s
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '281719471', response.authorization
    assert response.test?, response.test.to_s
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.capture(@amount, '281719471', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '281719471', response.authorization
    assert response.test?, response.test.to_s
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?, response.test.to_s
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('281719471', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '3533347610', response.authorization
    assert response.test?, response.test.to_s
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, '281719471', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '3533343128', response.authorization
    assert response.test?, response.test.to_s
  end

  def test_successful_store_profile
    @gateway.expects(:ssl_post).returns(successful_store_profile_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_equal "337907840", response.params['customer_vault_id']
    assert response.test?, response.test.to_s
  end

  def test_successful_unstore_profile
    @gateway.expects(:ssl_post).returns(successful_unstore_profile_response)

    assert response = @gateway.unstore("337907840", @options)
    assert_instance_of Response, response
    assert_equal "Customer Deleted", response.params['responsetext']
    assert response.test?, response.test.to_s
  end

  private

  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=100"
  end

  def failed_purchase_response
    "response=3&responsetext=DECLINE&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=300"
  end

  def successful_void_response
    "response=1&responsetext=Transaction Void Successful&authcode=123456&transactionid=3533347610&avsresponse=&cvvresponse=&orderid=&type=void&response_code=100"
  end

  def successful_refund_response
    "response=1&responsetext=SUCCESS&authcode=&transactionid=3533343128&avsresponse=&cvvresponse=&orderid=&type=refund&response_code=100&customer_vault_id=286214357"
  end

  def successful_store_profile_response
    "response=1&responsetext=Customer Added&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100&customer_vault_id=337907840"
  end

  def successful_unstore_profile_response
    "response=1&responsetext=Customer Deleted&authcode=&transactionid=&avsresponse=&cvvresponse=&orderid=&type=&response_code=100"
  end
end
