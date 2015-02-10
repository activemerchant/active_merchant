require 'test_helper'

class RemoteWhiteTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_\h+/
  CUSTOMER_ID_REGEX = /cus_\h+/

  def setup
    @gateway = WhiteGateway.new(fixtures(:white))

    @amount = 1000
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000000000000002')

    @options = {
      description:          'ActiveMerchant Test Purchase',
      statement_descriptor: 'Test Descriptor',
      email:                'wow@example.com',
      ip:                   '192.168.0.1'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.params["state"] == 'captured'
    assert response.params["statement_descriptor"] == 'Test Descriptor'
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Charge was declined.", response.message
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_authorization_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Charge was declined.", response.message
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization, { reason: 'Client request' })
    assert_success refund
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {
      description: "Active Merchant Test Customer",
      email: "email@example.com",
      ip: "192.168.0.1"
    })

    assert_success response
    assert_match CUSTOMER_ID_REGEX, response.authorization
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["cards"].first
    assert_equal response.params["default_card_id"], first_card["id"]
    assert_equal @credit_card.last_digits, first_card["last4"]
  end

  def test_successful_purchase_with_customer_id
    assert customer = @gateway.store(@credit_card, {
      description: "Active Merchant Test Customer",
      email: "email@example.com",
      ip: "192.168.0.1"
    })

    assert_success customer

    assert response = @gateway.purchase(@amount, customer.authorization, @options)
    assert_success response
  end
end
