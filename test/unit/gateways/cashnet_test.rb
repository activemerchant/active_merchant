require 'test_helper'

class Cashnet < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CashnetGateway.new(
      merchant: 'X',
      operator: 'X',
      password: 'test123',
      merchant_gateway_name: 'X'
    )
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1234', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Invalid expiration date, no expiration date provided', response.message
    assert_equal '', response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.refund(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1234', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Refund amounts should be expressed as positive amounts', response.message
    assert_equal '', response.authorization
  end

  def test_supported_countries
    assert_equal ['US'], CashnetGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb],  CashnetGateway.supported_cardtypes
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, order_id: '#1001')
    assert_equal '#1001', result[:order_number]
  end

  def test_add_creditcard
    result = {}
    @gateway.send(:add_creditcard, result, @credit_card)
    assert_equal @credit_card.number, result[:cardno]
    assert_equal @credit_card.verification_value, result[:cid]
    assert_equal '0915', result[:expdate]
    assert_equal 'Longbob Longsen', result[:card_name_g]
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, billing_address: {address1: '123 Test St.', address2: '5F', city: 'Testville', zip: '12345', state: 'AK'} )

    assert_equal ["addr_g", "city_g", "state_g", "zip_g"], result.stringify_keys.keys.sort
    assert_equal '123 Test St.,5F', result[:addr_g]
    assert_equal 'Testville', result[:city_g]
    assert_equal 'AK', result[:state_g]
    assert_equal '12345', result[:zip_g]
  end

  def test_add_customer_data
    result = {}
    @gateway.send(:add_customer_data, result, email: 'test@test.com')
    assert_equal 'test@test.com', result[:email_g]
  end

  def test_action_meets_minimum_requirements
    params = {
      amount: "1.01",
    }

    @gateway.send(:add_creditcard, params, @credit_card)
    @gateway.send(:add_invoice, params, {})

    assert data = @gateway.send(:post_data, 'SALE', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /#{key}=/)
    end
  end

  def test_successful_purchase_with_fname_and_lname
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, {})
    end.check_request do |method, endpoint, data, headers|
      assert_match(/fname=Longbob/, data)
      assert_match(/lname=Longsen/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  def minimum_requirements
    %w(command merchant operator station password amount custcode itemcode)
  end

  def successful_refund_response
    "<cngateway>result=0&respmessage=Success&tx=1234</cngateway>"
  end

  def failed_refund_response
    "<cngateway>result=305&respmessage=Failed</cngateway>"
  end

  def successful_purchase_response
    "<cngateway>result=0&respmessage=Success&tx=1234</cngateway>"
  end

  def failed_purchase_response
    "<cngateway>result=7&respmessage=Failed</cngateway>"
  end
end
