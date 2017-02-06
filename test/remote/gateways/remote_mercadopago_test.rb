require 'test_helper'

class RemoteMercadopagoTest < Test::Unit::TestCase
  def setup
    @gateway = MercadopagoGateway.new(fixtures(:mercadopago))

    @amount = 100
    @credit_card = {
        payment_method_id: 'visa',
        email:"user@example.com",
        cardNumber:"4509 9535 6623 3704",
        security_code: "200",
        expiration_month: "10",
        expiration_year: "2019",
        security_code_id: "200",
        cardholder: {
            name: "APRO",
            identification: {
                number: "987698",
                type: "DNI"
            }
        }
    }
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      email: "joe@example.com",
      idempotency_key: Random.rand(500000).to_s
    }
  end

  def test_successful_purchase
    @options[:idempotency_key] =  Random.rand(5433444).to_s
    @credit_card[:cardholder][:name] = 'APRO'
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
      idempotency_key: Random.rand(5000000).to_s
    }
    @credit_card[:cardholder][:name] = 'APRO'
    response = @gateway.purchase(@amount,@credit_card, options)
    assert_success response
    assert_equal 'approved', response.params['status']
  end

  def test_failed_purchase
    @options[:idempotency_key] =  Random.rand(5000000).to_s
    card = @credit_card.dup
    card[:cardholder][:name] = 'FUND'
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_equal 'rejected', response.params['status']
  end


  def test_successful_refund
    @options[:idempotency_key] =  Random.rand(5000000).to_s
    @credit_card[:cardholder][:name] = 'APRO'
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert refund.params['id'].present?, "Id must be returned"
  end

  def test_partial_refund
    @options[:idempotency_key] =  Random.rand(534534).to_s
    @credit_card[:cardholder][:name] = 'APRO'
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    @options[:idempotency_key] =  Random.rand(5000000).to_s
    response = @gateway.refund(@amount, '876867')
    assert_failure response
    assert_equal 404, response.params['status']
  end


end
