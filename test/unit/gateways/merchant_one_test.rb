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

  private

  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=100"
  end

  def failed_purchase_response
    "response=3&responsetext=DECLINE&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=300"
  end
end
