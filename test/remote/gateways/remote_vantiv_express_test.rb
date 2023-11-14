require 'test_helper'

class RemoteVantivExpressTest < Test::Unit::TestCase
  def setup
    @gateway = VantivExpressGateway.new(fixtures(:element))

    @amount = rand(1000..2000)
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('6060704495764400')
    @check = check
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }

    @google_pay_network_token = network_tokenization_credit_card(
      '6011000400000000',
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
      eci: '05',
      transaction_id: 'abc123',
      source: :apple_pay
    )
  end

  def test_successful_purchase_and_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_failed_purchase
    @amount = 20
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CARD INFO', response.message
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

  def test_successful_purchase_with_card_present_code_string
    response = @gateway.purchase(@amount, @credit_card, @options.merge(card_present_code: 'Present'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_payment_type_string
    response = @gateway.purchase(@amount, @credit_card, @options.merge(payment_type: 'NotUsed'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_submission_type_string
    response = @gateway.purchase(@amount, @credit_card, @options.merge(submission_type: 'NotUsed'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_duplicate_check_disable_flag
    amount = @amount

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_check_disable_flag: true))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_check_disable_flag: false))
    assert_failure response
    assert_equal 'Duplicate', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'true'))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_check_disable_flag: 'xxx'))
    assert_failure response
    assert_equal 'Duplicate', response.message
  end

  def test_successful_purchase_with_duplicate_override_flag
    amount = @amount

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_override_flag: true))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_override_flag: false))
    assert_failure response
    assert_equal 'Duplicate', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_override_flag: 'true'))
    assert_success response
    assert_equal 'Approved', response.message

    response = @gateway.purchase(amount, @credit_card, @options.merge(duplicate_override_flag: 'xxx'))
    assert_failure response
    assert_equal 'Duplicate', response.message
  end

  def test_successful_purchase_with_terminal_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(terminal_id: '02'))
    assert_success response
    assert_equal 'Approved', response.message
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
        special_program_code: 'AdvanceDeposit',
        charge_type: 'Restaurant'
      },
      card_holder_present_code: '2',
      card_input_code: '4',
      card_present_code: 'NotPresent',
      cvv_presence_code: '2',
      market_code: 'HotelLodging',
      terminal_capability_code: 'ChipReader',
      terminal_environment_code: 'LocalUnattended',
      terminal_type: 'Mobile',
      terminal_id: '0001',
      ticket_number: 182726718192
    }
    response = @gateway.purchase(@amount, @credit_card, lodging_options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_enum_fields
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
        prestigious_property_code: 1,
        special_program_code: 2,
        charge_type: 2
      },
      card_holder_present_code: '2',
      card_input_code: '4',
      card_present_code: 0,
      cvv_presence_code: 2,
      market_code: 5,
      terminal_capability_code: 5,
      terminal_environment_code: 6,
      terminal_type: 2,
      terminal_id: '0001',
      ticket_number: 182726718192
    }
    response = @gateway.purchase(@amount, @credit_card, lodging_options)
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

  def test_successful_authorize_capture_and_void_with_apple_pay
    auth = @gateway.authorize(3100, @apple_pay_network_token, @options)
    assert_success auth

    assert capture = @gateway.capture(3200, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_verify_with_apple_pay
    response = @gateway.verify(@apple_pay_network_token, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    @amount = 20
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'INVALID CARD INFO', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'TransactionID required', response.message
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

  def test_successful_partial_capture_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture

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
    gateway = ElementGateway.new(account_id: '3', account_token: '3', application_id: '3', acceptor_id: '3', application_name: '3', application_version: '3')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid AccountToken}, response.message
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
