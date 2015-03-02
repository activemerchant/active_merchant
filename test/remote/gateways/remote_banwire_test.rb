require 'test_helper'

class RemoteBanwireTest < Test::Unit::TestCase
  def setup

    @gateway = BanwireGateway.new(fixtures(:banwire))
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
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "success", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "success", response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal "success", purchase.message

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
    assert_equal "success", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, '0')
    assert_failure response
  end
end
