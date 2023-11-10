require 'test_helper'

class RemoteElementTest < Test::Unit::TestCase
  def setup
    @gateway = ElementGateway.new(fixtures(:element))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @check = check
    @options = {
      order_id: '2',
      billing_address: address.merge(zip: '87654'),
      description: 'Store Purchase',
      duplicate_override_flag: 'true'
    }

    @google_pay_network_token = network_tokenization_credit_card(
      '4000100011112224',
      month: '01',
      year: Time.new.year + 2,
      first_name: 'Jane',
      last_name: 'Doe',
      verification_value: '888',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '05',
      transaction_id: '123456789',
      source: :google_pay
    )

    @apple_pay_network_token = network_tokenization_credit_card(
      '4895370015293175',
      month: '10',
      year: Time.new.year + 2,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      payment_cryptogram: 'CeABBJQ1AgAAAAAgJDUCAAAAAAA=',
      eci: '07',
      transaction_id: 'abc123',
      source: :apple_pay
    )
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_match %r{Street address and 5-digit postal code match.}, response.avs_result['message']
    assert_match %r{CVV matches}, response.cvv_result['message']
  end

  def test_failed_purchase
    @amount = 51
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_purchase_with_echeck
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_payment_account_token
    response = @gateway.store(@credit_card, @options)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_shipping_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge(shipping_address: address(address1: 'Shipping')))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_billing_email
    response = @gateway.purchase(@amount, @credit_card, @options.merge(email: 'test@example.com'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_card_present_code
    response = @gateway.purchase(@amount, @credit_card, @options.merge(card_present_code: 'Present'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_payment_type
    response = @gateway.purchase(@amount, @credit_card, @options.merge(payment_type: 'NotUsed'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_submission_type
    response = @gateway.purchase(@amount, @credit_card, @options.merge(submission_type: 'NotUsed'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_duplicate_check_disable_flag
    response = @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: true))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: false))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'true'))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'xxx'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_duplicate_override_flag
    options = {
      order_id: '2',
      billing_address: address.merge(zip: '87654'),
      description: 'Store Purchase'
    }

    response = @gateway.purchase(@amount, @credit_card, options.merge(duplicate_override_flag: true))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(@amount, @credit_card, options.merge(duplicate_override_flag: 'true'))
    assert_success response
    assert_equal 'Approved', response.message

    # Due to the way these new creds are configured, they fail on duplicate transactions.
    # We expect failures if duplicate_override_flag: false
    response = @gateway.purchase(@amount, @credit_card, options.merge(duplicate_override_flag: false))
    assert_failure response
    assert_equal 'Duplicate', response.message

    response = @gateway.purchase(@amount, @credit_card, options.merge(duplicate_override_flag: 'xxx'))
    assert_failure response
    assert_equal 'Duplicate', response.message
  end

  def test_successful_purchase_with_lodging_and_all_other_fields
    lodging_options = {
      order_id: '2',
      billing_address: address.merge(zip: '87654'),
      description: 'Store Purchase',
      duplicate_override_flag: 'true',
      lodging: {
        agreement_number: SecureRandom.hex(12),
        check_in_date: 20250910,
        check_out_date: 20250915,
        room_amount: 1000,
        room_tax: 0,
        no_show_indicator: 0,
        duration: 5,
        customer_name: 'francois dubois',
        client_code: 'Default',
        extra_charges_detail: '01',
        extra_charges_amounts: 'Default',
        prestigious_property_code: 'DollarLimit500',
        special_program_code: 'Sale',
        charge_type: 'Restaurant'
      },
      card_holder_present_code: 'ECommerce',
      card_input_code: 'ManualKeyed',
      card_present_code: 'NotPresent',
      cvv_presence_code: 'NotProvided',
      market_code: 'HotelLodging',
      terminal_capability_code: 'KeyEntered',
      terminal_environment_code: 'ECommerce',
      terminal_type: 'ECommerce',
      terminal_id: '0001',
      ticket_number: 182726718192
    }
    response = @gateway.purchase(@amount, @credit_card, lodging_options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_terminal_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(terminal_id: '02'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_merchant_descriptor
    response = @gateway.purchase(@amount, @credit_card, @options.merge(merchant_descriptor: 'Flowerpot Florists'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay_network_token, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay_network_token, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    @amount = 51
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'TransactionID required', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'TransactionID required', response.message
  end

  def test_successful_credit
    credit_options = @options.merge({ ticket_number: '1', market_code: 'FoodRestaurant', merchant_supplied_transaction_id: '123' })
    credit = @gateway.credit(@amount, @credit_card, credit_options)

    assert_success credit
  end

  def test_failed_credit
    credit = @gateway.credit(nil, @credit_card, @options)

    assert_failure credit
    assert_equal 'TransactionAmount required', credit.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'TransactionAmount required', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r{PaymentAccount created}, response.message
  end

  def test_invalid_login
    gateway = ElementGateway.new(account_id: '', account_token: '', application_id: '', acceptor_id: '', application_name: '', application_version: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid Request}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:account_token], transcript)
  end

  def test_transcript_scrubbing_with_echeck
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:account_token], transcript)
  end
end
