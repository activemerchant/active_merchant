require 'test_helper'

class RemoteCheckoutV2Test < Test::Unit::TestCase
  def setup
    @gateway = CheckoutV2Gateway.new(fixtures(:checkout_v2))

    @amount = 200
    @credit_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: '2025')
    @expired_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: '2010')
    @declined_card = credit_card('42424242424242424', verification_value: '234', month: '6', year: '2025')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Purchase',
      email: 'longbob.longsen@example.com'
    }
    @additional_options = @options.merge(
      card_on_file: true,
      transaction_indicator: 2,
      previous_charge_id: 'pay_123'
    )
    @additional_options_3ds = @options.merge(
      execute_threed: true,
      three_d_secure: {
        version: '1.0.2',
        eci: '06',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        xid: 'MDAwMDAwMDAwMDAwMDAwMzIyNzY='
      }
    )
    @additional_options_3ds2 = @options.merge(
      execute_threed: true,
      three_d_secure: {
        version: '2.0.0',
        eci: '06',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        ds_transaction_id: 'MDAwMDAwMDAwMDAwMDAwMzIyNzY='
      }
    )
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

  def test_successful_purchase_with_additional_options
    response = @gateway.purchase(@amount, @credit_card, @additional_options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_includes_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
  end

  def test_successful_authorize_includes_avs_result
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
  end

  def test_successful_purchase_includes_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_authorize_includes_cvv_result
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_purchase_with_descriptors
    options = @options.merge(descriptor_name: 'shop', descriptor_city: 'london')
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
    response = @gateway.purchase(@amount, @credit_card, ip: '96.125.185.52')
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_avs_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, billing_address: address.update(address1: 'Test_A'))
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_avs_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, billing_address: address.update(address1: 'Test_A'))
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_additional_options
    auth = @gateway.authorize(@amount, @credit_card, @additional_options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds
    auth = @gateway.authorize(@amount, @credit_card, @additional_options_3ds)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds2
    auth = @gateway.authorize(@amount, @credit_card, @additional_options_3ds2)
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
    assert_match %r{request_invalid: card_number_invalid}, response.message
  end

  def test_expired_card_returns_error_code
    response = @gateway.purchase(@amount, @expired_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_expired', response.message
    assert_equal 'request_invalid: card_expired', response.error_code
  end
end
