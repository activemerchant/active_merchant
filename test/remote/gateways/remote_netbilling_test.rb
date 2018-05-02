require 'test_helper'

class RemoteNetbillingTest < Test::Unit::TestCase
  def setup
    @gateway = NetbillingGateway.new(fixtures(:netbilling))

    @credit_card = credit_card('4444111111111119')

    @address = {  :address1 => '1600 Amphitheatre Parkway',
                  :city => 'Mountain View',
                  :state => 'CA',
                  :country => 'US',
                  :zip => '94043',
                  :phone => '650-253-0001'
                }

    @options = {
      :billing_address => @address,
      :description => 'Internet purchase',
      :order_id => 987654321
    }

    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
  end

  def test_successful_repeat_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?

    transaction_id = response.authorization
    assert response = @gateway.purchase(@amount, transaction_id, @options)
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
    assert response.test?
  end

  def test_unsuccessful_repeat_purchase
    assert response = @gateway.purchase(@amount, '1111', @options)
    assert_failure response
    assert_match(/no record found/i, response.message)
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
  end

  def test_unsuccessful_store
    assert response = @gateway.store(credit_card('123'), @options)
    assert_failure response
    assert_match(/invalid credit card number/i, response.message)
  end

  def test_unsuccessful_purchase
    @credit_card.year = '2006'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1111')
    assert_failure response
    assert_match(/no record found/i, response.message)
  end

  def test_invalid_login
    gateway = NetbillingGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match(/missing/i, response.message)
    assert_failure response
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization.present?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message

    assert refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization.present?
    assert_equal NetbillingGateway::SUCCESS_MESSAGE, response.message

    # The test environment doesn't support void
    assert void_response = @gateway.void(response.authorization)
    assert_failure void_response
    assert_match(/error/i, void_response.message)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
