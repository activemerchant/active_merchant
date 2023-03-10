require 'test_helper'

class RemoteCommerceHubTest < Test::Unit::TestCase
  def setup
    # Uncomment the sleep if you want to run the entire set of remote tests without
    # getting 'The transaction limit was exceeded. Please try again!' errors
    # sleep 10

    @gateway = CommerceHubGateway.new(fixtures(:commerce_hub))

    @amount = 1204
    @credit_card = credit_card('4005550000000019', month: '02', year: '2035', verification_value: '123', first_name: 'John', last_name: 'Doe')
    @google_pay = network_tokenization_credit_card('4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :google_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
    @apple_pay = network_tokenization_credit_card('4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :apple_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
    @declined_apple_pay = network_tokenization_credit_card('4000300011112220',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :apple_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
    @declined_card = credit_card('4000300011112220', month: '02', year: '2035', verification_value: '123')
    @master_card = credit_card('5454545454545454', brand: 'master')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_gsf_mit
    @options[:data_entry_source] = 'ELECTRONIC_PAYMENT_TERMINAL'
    @options[:pos_entry_mode] = 'CONTACTLESS'
    response = @gateway.purchase(@amount, @master_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_cit_with_gsf
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'cardholder',
      initiator: 'unscheduled'
    }
    @options[:eci_indicator] = 'CHANNEL_ENCRYPTED'
    @options[:stored_credential] = stored_credential_options
    response = @gateway.purchase(@amount, @master_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_failed_avs_cvv_response_codes
    @options[:billing_address] = {
      address1: '112 Main St.',
      city: 'Atlanta',
      state: 'GA',
      zip: '30301',
      country: 'US'
    }
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'X', response.cvv_result['code']
    assert_equal 'CVV check not supported for card', response.cvv_result['message']
    assert_nil response.avs_result['code']
  end

  def test_successful_purchase_with_billing_and_shipping
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: address, shipping_address: address }))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_stored_credential_framework
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'recurring',
      initiator: 'merchant'
    }
    first_response = @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    assert_success first_response

    ntxid = first_response.params['transactionDetails']['retrievalReferenceNumber']
    stored_credential_options = {
      initial_transaction: false,
      reason_type: 'recurring',
      initiator: 'merchant',
      network_transaction_id: ntxid
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Unable to assign card to brand: Invalid.', response.message
    assert_equal '104', response.error_code
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  # Commenting out until we are able to resolve issue with capture transactions failing at gateway
  # def test_successful_authorize_and_capture
  #   authorize = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success authorize

  #   capture = @gateway.capture(@amount, authorize.authorization)
  #   assert_success capture
  # end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Unable to assign card to brand: Invalid.', response.message
  end

  def test_successful_authorize_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.void(response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_void
    response = @gateway.void('123', @options)
    assert_failure response
    assert_equal 'Referenced transaction is invalid or not found', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'VERIFIED', response.message
  end

  def test_successful_verify_with_address
    @options[:billing_address] = {
      address1: '112 Main St.',
      city: 'Atlanta',
      state: 'GA',
      zip: '30301',
      country: 'US'
    }

    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal 'VERIFIED', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)

    assert_failure response
  end

  def test_successful_purchase_and_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.refund(nil, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_and_partial_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.refund(@amount - 1, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, 'abc123|123', @options)
    assert_failure response
    assert_equal 'Referenced transaction is invalid or not found', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'TOKENIZE', response.message
  end

  def test_successful_store_with_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'TOKENIZE', response.message

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'DecryptedWallet', response.params['source']['sourceType']
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'DecryptedWallet', response.params['source']['sourceType']
  end

  def test_failed_purchase_with_declined_apple_pay
    response = @gateway.purchase(@amount, @declined_apple_pay, @options)
    assert_failure response
    assert_equal 'Unable to assign card to brand: Invalid.', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
    assert_scrubbed(@gateway.options[:api_secret], transcript)
  end

  def test_transcript_scrubbing_apple_pay
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
    assert_scrubbed(@gateway.options[:api_secret], transcript)
    assert_scrubbed(@apple_pay.payment_cryptogram, transcript)
  end
end
