require 'test_helper'

class RemoteMerchantFirstTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantFirstGateway.new(fixtures(:merchant_first))

    @amount = 100
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('5454545454545454', year: (Time.now - 1.year).year)
    @credit_card_store = credit_card('5454545454545454', verification_value: nil)
    @options = {
      currency: 'USD',
      gateway: 'merchant partners',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '0: Approved | ', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '0: Approved | ', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '50: General Decline | Invalid Expiration Date', response.message
    assert_equal 'processing_error', response.error_code
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

  def test_successful_store
    response = @gateway.store(@credit_card_store, @options)
    assert_success response
  end

  def test_successful_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.params['mcs_transaction_id'], @options)
    assert_success void
  end

  def test_failed_void
    # will fail because MF expects a valid MCSTransactionID
    # The rescue is necessary as MF yield HTTP 500 (internal server error) :-(
    void = @gateway.void('123', @options) rescue Response.new(false, 'Server was unable to process request.')
    assert_failure void
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.params['mcs_transaction_id'], @options)
    assert_success refund
  end

  def test_failed_refund
    # will fail because MF expects a valid MCSTransactionID
    # The rescue is necessary as MF yield HTTP 500 (internal server error) :-(
    refund = @gateway.refund(@amount, '123', @options) rescue Response.new(false, 'Server was unable to process request.')
    assert_failure refund
  end
end
