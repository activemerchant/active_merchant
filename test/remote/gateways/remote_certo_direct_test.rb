require 'test_helper'

class CertoDirectTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = CertoDirectGateway.new(fixtures(:certo_direct))
    @amount = 100
    @credit_card = credit_card('4012888888881881', :month => 1)
    @options = {
      :billing_address => {
        :address1 => 'Infinite Loop 1',
        :country => 'US',
        :state => 'TX',
        :city => 'Gotham',
        :zip => '23456',
        :phone => '+1-132-12345678',
        :first_name => 'John',
        :last_name => 'Doe'
      },
      :email           => 'john.doe@example.com',
      :currency        => 'USD',
      :ip              => '127.0.0.1',
      :description => 'Test Order of ActiveMerchant.'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Transaction was successfully processed', response.message
    assert response.authorization
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'invalid transaction data', response.message
  end

  def test_bad_login
    gateway = CertoDirectGateway.new(:login => 'X', :password => 'Y')

    assert response = gateway.purchase(@amount, @credit_card, @options)

    assert_equal Response, response.class
    assert_match(/Authentication was failed/, response.message)
    assert_equal false, response.success?
  end

  def test_fail_purchase
    @credit_card.month = 2

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'Transaction was declined', response.message
  end

  def test_purchase_and_refund
    # purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Transaction was successfully processed', response.message
    assert order_id = response.authorization

    # refund
    assert response = @gateway.refund(@amount, order_id, :reason => 'Merchant request.')
    assert_success response
    assert_equal 'Transaction was successfully processed', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'Transaction was successfully processed', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(@amount, authorization.authorization)
    assert_success void
    assert_equal 'Transaction was successfully processed', void.message
  end

  def test_sale_and_recurring
    assert sale = @gateway.purchase(@amount, @credit_card, @options)
    assert_success sale

    assert recurring = @gateway.recurring(sale.authorization)
    assert_success recurring
    assert_equal 'Recurring Transaction was successfully processed', recurring.message
  end

  def test_sale_and_recurring_overriding_details
    assert sale = @gateway.purchase(@amount, @credit_card, @options)
    assert_success sale

    assert recurring = @gateway.recurring(sale.authorization,
                                          :amount => 99,
                                          :currency => 'USD',
                                          :shipping => 1)

    assert_success recurring
    assert_equal 'Recurring Transaction was successfully processed', recurring.message
  end
end
