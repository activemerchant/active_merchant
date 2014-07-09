require 'test_helper'

class RemoteBalancedTest < Test::Unit::TestCase
  def setup
    @gateway = BalancedGateway.new(fixtures(:balanced))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4222222222222220')
    @declined_card = credit_card('4444444444444448')

    @options = {
      email: 'john.buyer@example.org',
      billing_address: address,
      description: 'Shopify Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
    assert_equal @amount, response.params['debits'][0]['amount']
  end

  def test_successful_purchase_with_outside_token
    outside_token = @gateway.store(@credit_card).params['cards'][0]['href']
    response = @gateway.purchase(@amount, outside_token, @options)
    assert_success response
    assert_equal "Success", response.message
    assert_equal @amount, response.params['debits'][0]['amount']
  end

  def test_purchase_with_invalid_card
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_match %r{call bank}i, response.message
  end

  def test_unsuccessful_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{Account Frozen}, response.message
  end

  def test_passing_appears_on_statement
    options = @options.merge(appears_on_statement_as: "Homer Electric")
    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal "BAL*Homer Electric", response.params['debits'][0]['appears_on_statement_as']
  end

  def test_passing_meta
    options = @options.merge(meta: { "order_number" => '12345' })
    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal options[:meta], response.params["debits"][0]["meta"]
  end

  def test_authorize_and_capture
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Success', authorize.message

    assert capture = @gateway.capture(@amount, authorize.authorization)
    assert_success capture
    assert_equal @amount, capture.params['debits'][0]['amount']
  end

  def test_authorize_and_capture_partial
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Success', authorize.message

    assert capture = @gateway.capture(@amount / 2, authorize.authorization)
    assert_success capture
    assert_equal @amount / 2, capture.params['debits'][0]['amount']
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_void_authorization
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    assert void = @gateway.void(authorize.authorization)
    assert_success void
    assert void.params["card_holds"][0]['voided_at'], void.inspect
  end

  def test_voiding_a_capture_not_allowed
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert authorize.authorization

    assert capture = @gateway.capture(@amount, authorize.authorization)
    assert_success capture
    assert capture.authorization

    void = @gateway.void(capture.authorization)
    assert_failure void
    assert_match %r{not found}i, void.message
  end

  def test_authorize_authorization
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_refund_purchase
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal @amount, refund.params['refunds'][0]['amount']
  end

  def test_refund_authorization
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert refund = @gateway.refund(@amount, auth.authorization)
    assert_success refund
  end

  def test_refund_partial_purchase
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount / 2, purchase.authorization)
    assert_success refund
    assert_equal @amount / 2, refund.params['refunds'][0]['amount']
  end

  def test_store
    new_email_address = '%d@example.org' % Time.now
    store = @gateway.store(@credit_card, {
        email: new_email_address
    })
    assert_instance_of String, store.authorization
  end

  def test_store_and_purchase
    store = @gateway.store(@credit_card)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization)
    assert_success purchase
  end

  def test_store_and_authorize
    store = @gateway.store(@credit_card)
    assert_success store

    authorize = @gateway.authorize(@amount, store.authorization)
    assert_success authorize
  end

  def test_passing_address_with_no_zip
    response = @gateway.purchase(@amount, @credit_card, address(zip: nil))
    assert_success response
  end

  def test_invalid_login
    gateway = BalancedGateway.new(
      login: ''
    )
    response = gateway.store(@credit_card)
    assert_match %r{credentials}i, response.message
  end
end
