require 'test_helper'

class RemoteVersaPayTest < Test::Unit::TestCase
  def setup
    @gateway = VersaPayGateway.new(fixtures(:versa_pay))
    @bad_gateway = VersaPayGateway.new(api_token: 'bad_token', api_key: 'bad_key')

    @amount = 500
    @credit_card = credit_card('4895281000000006', verification_value: '123', month: 12, year: Time.now.year + 1)
    @credit_card_match_cvv = credit_card('4895281000000006', verification_value: '234', month: 12, year: Time.now.year + 1)
    @credit_card_not_match_cvv = credit_card('4895281000000006', verification_value: '345', month: 12, year: Time.now.year + 1)
    @decline_credit_card = credit_card('4264280001234500')
    @no_valid_date_credit_card = credit_card('4895281000000006', month: 9, year: Time.now.year - 1)

    @options = {
      order_id: 'ABCDF',
      description: 'An authorize',
      email: 'john.smith@test.com',
      order_number: SecureRandom.uuid,
      billing_address: address # billing address is required for all transactions
    }

    @options_with_shipping = @options.dup.merge({ shipping_address: address })
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal response.message, 'Succeeded'
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'authorize'
    assert_nil response.error_code
  end

  def test_successful_authorize_with_shipping_address
    response = @gateway.authorize(@amount, @credit_card, @options_with_shipping)

    assert_success response
    assert_equal response.message, 'Succeeded'
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'authorize'
  end

  def test_failed_authorize_declined_credit_card
    response = @gateway.authorize(@amount, @decline_credit_card, @options)

    assert_failure response
    assert_equal response.message, 'gateway_error_message: DECLINED | gateway_response_errors: [gateway - DECLINED]'
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'verify'

    assert_equal response.error_code, 'gateway_error_code: 567.005 | response_code: 999'
  end

  def test_failed_authorize_declined_amount
    response = @gateway.authorize(501, @decline_credit_card, @options)
    assert_failure response
    assert_equal response.message, 'gateway_error_message: DECLINED | gateway_response_errors: [gateway - DECLINED]'
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'verify'

    assert_equal response.error_code, 'gateway_error_code: 567.005 | response_code: 999'
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'sale'
  end

  def test_failed_purchase_declined_credit_card
    response = @gateway.purchase(@amount, @decline_credit_card, @options)

    assert_failure response
    assert_equal response.message, 'gateway_error_message: DECLINED | gateway_response_errors: [gateway - DECLINED]'
    assert_equal response.params['transactions'][0]['action'], 'verify'
    assert_equal response.error_code, 'gateway_error_code: 567.005 | response_code: 999'
  end

  def test_failed_purchase_declined_amount
    response = @gateway.purchase(501, @decline_credit_card, @options)
    assert_failure response
    assert_equal response.message, 'gateway_error_message: DECLINED | gateway_response_errors: [gateway - DECLINED]'
    assert_equal response.params['transactions'][0]['action'], 'verify'
    assert_equal response.error_code, 'gateway_error_code: 567.005 | response_code: 999'
  end

  def test_failed_purchase_no_billing_address
    options_no_address = @options.dup
    options_no_address.delete(:billing_address).delete(:shipping_address)
    response = @gateway.purchase(@amount, @credit_card, options_no_address)
    assert_failure response

    assert_equal response.message, 'errors: fund_address_unspecified'

    assert_equal response.error_code, 'response_code: 999'
  end

  def test_failed_purchase_no_found_credit_card
    response = @gateway.purchase(@amount, @no_valid_date_credit_card, @options)
    assert_failure response
    assert_equal response.message, 'errors: Validation failed: Credit card gateway token not found'
    assert_equal response.error_code, 'response_code: 999'
  end

  def test_successful_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)

    assert_success authorize
    response = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal authorize.params['order'], response.params['order']
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'capture'
  end

  def test_successful_partial_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)

    assert_success authorize
    response = @gateway.capture(@amount - 100, authorize.authorization, @options)
    assert_success response

    assert_equal 'Succeeded', response.message
    assert_equal authorize.params['order'], response.params['order']
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'capture'
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal response.message, 'Succeeded'
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'verify'
  end

  # verify return both avs_response and cvv_response

  def test_avs_match_cvv_not_proccessed
    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal response.message, 'Succeeded'
    assert_equal response.avs_result, { 'code' => 'D', 'message' => 'Street address and postal code match.', 'postal_match' => 'Y', 'street_match' => 'Y' }
    assert_equal response.cvv_result, { 'code' => 'P', 'message' => 'CVV not processed' }
  end

  def test_avs_match_cvv_match
    response = @gateway.verify(@credit_card_match_cvv, @options)

    assert_success response
    assert_equal response.message, 'Succeeded'

    # verify return both avs_response and cvv_response
    assert_equal response.avs_result, { 'code' => 'D', 'message' => 'Street address and postal code match.', 'postal_match' => 'Y', 'street_match' => 'Y' }
    assert_equal response.cvv_result, { 'code' => 'M', 'message' => 'CVV matches' }
  end

  def test_avs_no_match_cvv_not_match
    options = @options.dup
    options[:billing_address][:address1] = '234 Elm Street'
    options[:billing_address][:zip] = 80803

    response = @gateway.verify(@credit_card_match_cvv, options)

    assert_failure response
    assert_equal response.message, 'gateway_response_errors: [gateway - Failed AVS Check]'

    # verify return both avs_response and cvv_response
    assert_equal response.avs_result, { 'code' => 'N', 'message' => "Street address and postal code do not match. For American Express: Card member's name, street address and postal code do not match.", 'postal_match' => 'N', 'street_match' => 'N' }
    assert_equal response.cvv_result, { 'code' => 'M', 'message' => 'CVV matches' }
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)

    assert_success authorize
    response = @gateway.void(authorize.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal authorize.params['order'], response.params['order']
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'void'
  end

  def test_failed_void
    response = @gateway.void('123456', @options)
    assert_failure response
    assert_equal response.message, 'errors: order_not_found' # come from a 500 HTTP error
    assert_equal response.error_code, 'response_code: 250'
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    response = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal purchase.params['order'], response.params['order']
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'refund'
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '123456', @options)
    assert_failure response
    assert_equal response.message, 'errors: order_not_found' # come from a 500 HTTP error
    assert_equal response.error_code, 'response_code: 250'
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'credit'
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @no_valid_date_credit_card, @options)
    assert_failure response
    assert_equal response.message, 'errors: Validation failed: Credit card gateway token not found'
    assert_equal response.error_code, 'response_code: 999'
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message

    wallet_token = response.params['wallet_token']
    fund_token = response.params['fund_token']
    assert_equal response.authorization, "#{wallet_token}|#{fund_token}"
    assert_include response.params, 'wallet_token'
    assert_include response.params, 'fund_token'
    assert_include response.params, 'wallets'
    assert_include response.params['wallets'][0], 'token'
    assert_include response.params['wallets'][0], 'credit_cards'
    assert_include response.params['wallets'][0]['credit_cards'][0], 'token'
    assert_match response.params['wallets'][0]['token'], response.authorization
    assert_match response.params['wallets'][0]['credit_cards'][0]['token'], response.authorization
  end

  def test_successful_purchase_after_store
    store = @gateway.store(@credit_card, @options)
    assert_success store
    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal @options[:order_id], response.params['order']
    assert_equal response.authorization, response.params['transaction']
    assert_equal response.params['transactions'][0]['action'], 'sale'
  end

  def test_successful_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store
    fund_token = store.params['fund_token']
    response = @gateway.unstore(store.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal response.authorization, fund_token
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.send(:basic_auth), transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end
