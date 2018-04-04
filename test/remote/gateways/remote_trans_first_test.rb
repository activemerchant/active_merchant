require 'test_helper'

class RemoteTransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(fixtures(:trans_first))

    @credit_card = credit_card('4485896261017708', verification_value: 999)
    @check = check
    @amount = 1201
    @options = {
      :order_id => generate_unique_id,
      :invoice => 'ActiveMerchant Sale',
      :billing_address => address
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?

    @gateway.void(response.authorization)
  end

  def test_successful_purchase_no_address
    @options.delete(:billing_address)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?

    @gateway.void(response.authorization)
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = ""
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_echeck_no_address
    @options.delete(:billing_address)
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_purchase_with_echeck_defaults
    @check = check(account_holder_type: nil, account_type: nil)
    assert response = @gateway.purchase(@amount, @check, @options)
    assert response.test?
    assert_success response
    assert !response.authorization.blank?
  end

  def test_failed_purchase
    @amount = 21
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Insufficient funds', response.message
  end

  def test_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  # Refunds can only be successfully run on settled transactions which take 24 hours 
  # def test_successful_refund
  #   assert purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount, purchase.authorization)
  #   assert_equal @amount, refund.params["amount"].to_i*100
  #   assert_success refund
  # end

  # def test_successful_partial_refund
  #   assert purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount-1, purchase.authorization)
  #   assert_equal @amount-1, refund.params["amount"].to_i*100
  #   assert_success refund
  # end

  def test_successful_refund_with_echeck
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_invalid_login
    gateway = TransFirstGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(1100, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_transcript_scrubbing_echecks
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
