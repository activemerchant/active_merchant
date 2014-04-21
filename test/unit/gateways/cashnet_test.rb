require 'test_helper'

class Cashnet < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CashnetGateway.new(
      :gateway_merchant_name => 'X',
      :station => 'X',
      :operator => 'X',
      :password => 'test123',
      :credit_card_payment_code => 'X',
      :customer_code => 'X',
      :item_code => 'X',
      :site_name => 'X'
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
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.refund(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '', response.authorization
  end

  def test_supported_countries
    assert_equal ['US'], CashnetGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb],  CashnetGateway.supported_cardtypes
  end

  private 

  def successful_refund_response
    "<cashnet>result=0&respmessage=Success&txno=1234</cashnet>"
  end

  def failed_refund_response
    "<cashnet>result=305&respmessage=Refund amounts should be expressed as positive amounts</cashnet>"
  end

  def successful_purchase_response
    "<cashnet>result=0&respmessage=Success&txno=1234</cashnet>"
  end

  def failed_purchase_response
    "<cashnet>result=7&respmessage= Invalid credit card number, no credit card number provided</cashnet>"
  end

end