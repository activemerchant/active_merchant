require 'test_helper'

class RemoteHostedpciTest < Test::Unit::TestCase
  def setup
    @gateway = HostedpciGateway.new(fixtures(:hostedpci))
    @credit_card_hash = {first_name: 'John',
                         last_name: 'Smith',
                         month: 1,
                         number: '4242000000404242',
                         verification_value: '200',
                         year: Time.now.year + 1}

    @amount = 100
    @credit_card = CreditCard.new(@credit_card_hash)
    @declined_card = CreditCard.new(@declined_credit_card_hash)

    @options = {
      :order_id => SecureRandom.hex(16),
      :ip=>'127.0.0.1',
      :customer=>'John Smith',
      :email=>'test@email.com',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_authorize

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'description: This transaction has been approved.; status_code:1; status_name:APPROVED', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'description: This transaction has been approved.; status_code:1; status_name:APPROVED', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'description: This transaction has been approved.; status_code:1; status_name:APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'API Call Error, check API Parameters. Error_ID: PPA_ACT_9', response.message
  end

  def test_invalid_login
    gateway = HostedpciGateway.new(fixtures(:hostedpci_no_login))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'API Call Error, check API Parameters. Error_ID: PPA_ACT_1', response.message
  end

end
