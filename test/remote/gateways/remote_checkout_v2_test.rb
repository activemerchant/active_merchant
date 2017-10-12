require 'test_helper'

class RemoteCheckoutV2Test < Test::Unit::TestCase
  def setup
    @gateway = CheckoutV2Gateway.new(fixtures(:checkout_v2))

    @amount = 200
    @credit_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: '2018')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Purchase',
      email: "longbob.longsen@example.com"
    }
  end

  def test_transcript_scrubbing
    declined_card = credit_card('4000300011112220', verification_value: '423')
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, declined_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(declined_card.number, transcript)
    assert_scrubbed(declined_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_includes_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'S', response.avs_result["code"]
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result["message"]
  end

  def test_successful_purchase_includes_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result["code"]
  end

  def test_successful_purchase_with_descriptors
    options = @options.merge(descriptor_name: "shop", descriptor_city: "london")
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, billing_address: address)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_without_phone_number
    response = @gateway.purchase(@amount, @credit_card, billing_address: address.update(phone: ''))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_ip
    response = @gateway.purchase(@amount, @credit_card, ip: "96.125.185.52")
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid Card Number', response.message
  end

  def test_avs_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, billing_address: address.update(address1: 'Test_A'))
    assert_failure response
    assert_equal '40111 - Street Match Only', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Invalid Card Number}, response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end
end
