require 'test_helper'

class BanwireTest < Test::Unit::TestCase
  def setup
    @gateway = BanwireGateway.new(:login => "desarrollo")

    @amount = 100

    @credit_card = ActiveMerchant::Billing::CreditCard.new(:number => '5134422031476272',
    :month => 12,
    :year => 2019,
    :verification_value => '162',
    :brand => 'mastercard',
    :name => 'carlos vargas')

    @declined_card = ActiveMerchant::Billing::CreditCard.new(:number => '4000300011112220',
    :month => 12,
    :year => 2019,
    :verification_value => '162',
    :brand => 'mastercard',
    :name => 'carlos vargas')

    @options = {
      order_id: '1',
      email: "cvargas@banwire.com",
      description: 'Store Purchase',
      cust_id: '1',
      phone: '2234567890',
      ip: '192.168.0.1',
      billing_address: {:address=>"prueba",:zip=>"12345"}
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "028713", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "1")
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    {
      'ID' => '117689',
      'CARD' => '1111',
      'ORD_ID' => '3486',
      'AUTH_CODE' => '028713'
    }.to_json
  end

  def failed_purchase_response
    {
      'ID' => '117689',
      'CARD' => '1111',
      'ORD_ID' => '1',
      'ERROR_CODE' => 0,
      'ERROR_MSG' => 'denied'
    }.to_json
  end

  def successful_authorize_response
    {
      'ID' => '117689',
      'CARD' => '1111',
      'ORD_ID' => '3486',
      'AUTH_CODE' => '028713'
    }.to_json
  end

  def failed_authorize_response
    {
      'ID' => '117689',
      'CARD' => '1111',
      'ORD_ID' => '1',
      'ERROR_CODE' => 0,
      'ERROR_MSG' => 'denied'
    }.to_json
  end

  def failed_refund_response
    {
      'status' => 'error',
      'code' => '130',
      'message' => 'Transacci\u00F3n invalida.'
    }.to_json
  end
end
