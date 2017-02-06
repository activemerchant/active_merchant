require 'test_helper'

class RemoteMercadopagoTest < Test::Unit::TestCase
  def setup
    @gateway = MercadopagoGateway.new(fixtures(:mercadopago))

    @amount = 100

    @credit_card = ActiveMerchant::Billing::CreditCard.new({
        brand: 'visa',
        number:"4509 9535 6623 3704",
        verification_value: "200",
        month: "10",
        year: "2019",
        first_name: "APRO",
        last_name:""
    })
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      email: "joe@example.com",
      order_id: Random.rand(500000).to_s,
      identification_number: "987698",
      identification_type: "DNI"
    }
  end

  def test_successful_purchase
    @options[:order_id] =  Random.rand(5433444).to_s
    @credit_card.name = 'APRO'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'approved', response.params['status']
  end

  def test_successful_purchase_with_more_options
    options = {
      description: 'Joe payment',
      email: "joe@example.com",
      identification_type: 'DNI',
      identification_number: "666666",
      metadata: {"data":"consumer"},
      additional_info: {ip_address:"127.0.0.1"},
      order_id: Random.rand(5000000).to_s
    }
    @credit_card.name = 'APRO'
    response = @gateway.purchase(@amount,@credit_card, options)
    assert_success response
    assert_equal 'approved', response.params['status']
  end

  def test_failed_purchase
    @options[:order_id] =  Random.rand(5000000).to_s
    card = @credit_card.dup
    card.name = 'FUND'
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_equal 'rejected', response.params['status']
  end


  def test_successful_refund
    @options[:order_id] =  Random.rand(5000000).to_s
    @credit_card.name = 'APRO'
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization,{order_id: Random.rand(5000000).to_s})
    assert_success refund
    assert refund.params['id'].present?, "Id must be returned"
  end

  def test_partial_refund
    @options[:order_id] =  Random.rand(500000).to_s
    @credit_card.name = 'APRO'
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    @options[:order_id] =  Random.rand(500000).to_s
    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '876867',{order_id: Random.rand(5000000).to_s})
    assert_failure response
    assert_equal 404, response.params['status']
  end


end
