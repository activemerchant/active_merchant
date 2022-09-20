require 'test_helper'

class RemoteShift4Test < Test::Unit::TestCase
  def setup
    @gateway = Shift4Gateway.new(fixtures(:shift4))
    access_token = @gateway.setup_access_token

    @gateway = Shift4Gateway.new(fixtures(:shift4).merge(access_token: access_token))

    @amount = 500
    @credit_card = credit_card('4000100011112224', verification_value: '333', first_name: 'John', last_name: 'Smith')
    @declined_card = credit_card('400030001111220', first_name: 'John', last_name: 'Doe')
    @unsupported_card = credit_card('4000100011112224', verification_value: '333', first_name: 'John', last_name: '成龙')
    @options = {}
    @extra_options = {
      clerk_id: '1576',
      notes: 'test notes',
      tax: '2',
      customer_reference: 'D019D09309F2',
      destination_postal_code: '94719',
      product_descriptors: %w(Hamburger Fries Soda Cookie)
    }
    @customer_address = {
      address1: '65 Easy St',
      zip: '65144'
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_authorize_with_extra_options
    response = @gateway.authorize(@amount, @credit_card, @options.merge(@extra_options))
    assert_success response
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_authorize_with_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_not_empty response.authorization

    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_success response
    assert_include 'Transaction successful', response.message
  end

  def test_successful_capture
    authorize_res = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_res
    response = @gateway.capture(@amount, authorize_res.authorization, @options)

    assert_success response
    assert_equal response.message, 'Transaction successful'
    assert response_result(response)['transaction']['invoice'].present?
    assert_equal response_result(response)['transaction']['invoice'], response_result(authorize_res)['transaction']['invoice']
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_include 'Transaction successful', response.message
  end

  def test_successful_purchase_with_customer_details
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: @customer_address }))
    assert_success response
    assert_include 'Transaction successful', response.message
  end

  def test_successful_purchase_with_extra_options
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options))
    assert_success response
  end

  def test_successful_purchase_with_stored_credential_framework
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'recurring'
    }
    @options[:merchant_time_zone] = 'EST'
    first_response = @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options.merge({ stored_credential: stored_credential_options })))
    assert_success first_response

    ntxid = first_response.params['result'].first['transaction']['cardOnFile']['transactionId']
    stored_credential_options = {
      initial_transaction: false,
      reason_type: 'recurring',
      network_transaction_id: ntxid
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options.merge({ stored_credential: stored_credential_options })))
    assert_success response
  end

  def test_successful_purchase_with_card_on_file_fields
    card_on_file_fields = {
      usage_indicator: '01',
      indicator: '01',
      scheduled_indicator: '01'
    }
    first_response = @gateway.purchase(@amount, @credit_card, @options.merge(card_on_file_fields))
    assert_success first_response

    ntxid = first_response.params['result'].first['transaction']['cardOnFile']['transactionId']
    card_on_file_fields = {
      usage_indicator: '02',
      indicator: '01',
      scheduled_indicator: '02',
      transaction_id: ntxid
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options.merge(card_on_file_fields)))
    assert_success response
  end

  def test_successful_purchase_with_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_not_empty response.authorization

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_include 'Transaction successful', response.message
  end

  def test_successful_purchase_with_store_having_customer_details
    response = @gateway.store(@credit_card, @options.merge({ billing_address: @customer_address }))
    assert_success response
    assert_not_empty response.authorization

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_include 'Transaction successful', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_card_on_file_fields
    card_on_file_fields = {
      usage_indicator: '01',
      indicator: '01',
      scheduled_indicator: '01'
    }
    first_response = @gateway.purchase(@amount, @credit_card, @options.merge(card_on_file_fields))
    assert_success first_response
    ntxid = first_response.params['result'].first['transaction']['cardOnFile']['transactionId']

    card_on_file_fields = {
      usage_indicator: '02',
      indicator: '01',
      scheduled_indicator: '02',
      transaction_id: ntxid
    }
    response = @gateway.verify(@credit_card, @options.merge(card_on_file_fields))
    assert_success response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed("0#{@credit_card.month}#{@credit_card.year.to_s[2..4]}", transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_include response.message, 'Card  for Merchant Id 0008628968 not found'
  end

  def test_failure_on_referral_transactions
    response = @gateway.purchase(67800, @credit_card, @options)
    assert_failure response
    assert_include 'Transaction declined', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_include response.message, 'Card  for Merchant Id 0008628968 not found'
  end

  def test_failed_authorize_with_error_message
    response = @gateway.authorize(@amount, @unsupported_card, @options)
    assert_failure response
    assert_equal response.message, 'Format \'UTF8: An unexpected continuatio\' invalid or incompatible with argument'
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_include response.message, 'Card  for Merchant Id 0008628968 not found'
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'YC', @options)
    assert_failure response
    assert_include response.message, 'record not posted'
  end

  def test_successful_refund
    res = @gateway.purchase(@amount, @credit_card, @options)
    assert_success res
    response = @gateway.refund(@amount, res.authorization, @options)
    assert_success response
  end

  def test_successful_refund_with_expiration_date
    res = @gateway.purchase(@amount, @credit_card, @options)
    assert_success res
    response = @gateway.refund(@amount, res.authorization, @options.merge({ expiration_date: '1235' }))
    assert_success response
  end

  def test_successful_void
    authorize_res = @gateway.authorize(@amount, @credit_card, @options)
    assert response = @gateway.void(authorize_res.authorization, @options)

    assert_success response
    assert_equal @options[:invoice], response_result(response)['transaction']['invoice']
  end

  def test_failed_void
    response = @gateway.void('', @options)
    assert_failure response
    assert_include response.message, 'Invoice Not Found'
  end

  private

  def response_result(response)
    response.params['result'][0]
  end
end
