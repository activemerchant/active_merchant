require 'test_helper'

class RemoteGlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))
    @gateway_preprod = GlobalCollectGateway.new(fixtures(:global_collect_preprod))
    @gateway_preprod.options[:url_override] = 'preproduction'

    @amount = 100
    @credit_card = credit_card('4567350000427977')
    @naranja_card = credit_card('5895620033330020', brand: 'naranja')
    @cabal_card = credit_card('6271701225979642', brand: 'cabal')
    @declined_card = credit_card('5424180279791732')
    @preprod_card = credit_card('4111111111111111')
    @accepted_amount = 4005
    @rejected_amount = 2997
    @options = {
      email: 'example@example.com',
      billing_address: address,
      description: 'Store Purchase'
    }
    @long_address = {
      billing_address: {
        address1: '1234 Supercalifragilisticexpialidociousthiscantbemorethanfiftycharacters',
        city: 'Portland',
        state: 'ME',
        zip: '09901',
        country: 'US'
      }
    }
    @preprod_options = {
      order_id: SecureRandom.hex(15),
      email: 'email@example.com',
      billing_address: address
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@accepted_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
  end

  def test_successful_purchase_with_naranja
    options = @preprod_options.merge(requires_approval: false, currency: 'ARS')
    response = @gateway_preprod.purchase(1000, @naranja_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
  end

  def test_successful_purchase_with_cabal
    options = @preprod_options.merge(requires_approval: false, currency: 'ARS')
    response = @gateway_preprod.purchase(1000, @cabal_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
  end

  def test_successful_purchase_with_fraud_fields
    options = @options.merge(
      fraud_fields: {
        'website' => 'www.example.com',
        'giftMessage' => 'Happy Day!'
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      sdk_identifier: 'Channel',
      sdk_creator: 'Bob',
      integrator: 'Bill',
      creator: 'Super',
      name: 'Cala',
      version: '1.0',
      extension_ID: '5555555'
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_installments
    options = @options.merge(number_of_installments: 2)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  # When requires_approval is true (or not present),
  # `purchase` will make both an `auth` and a `capture` call
  def test_successful_purchase_with_requires_approval_true
    options = @options.merge(requires_approval: true)

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
  end

  # When requires_approval is false, `purchase` will only make an `auth` call
  # to request capture (and no subsequent `capture` call).
  def test_successful_purchase_with_requires_approval_false
    options = @options.merge(requires_approval: false)

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
  end

  def test_successful_authorize_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.1.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        acs_transaction_id: '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
        cavv_algorithm: 1,
        authentication_response_status: 'Y'
      }
    )

    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_match 'jJ81HADVRtXfCBATEp01CJUAAAA=', response.params['payment']['paymentOutput']['cardPaymentMethodSpecificOutput']['threeDSecureResults']['cavv']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_airline_data
    options = @options.merge(
      airline_data: {
        code: 111,
        name: 'Spreedly Airlines',
        flight_date: '20190810',
        passenger_name: 'Randi Smith',
        is_eticket: 'true',
        is_restricted_ticket: 'true',
        is_third_party: 'true',
        issue_date: 'tday',
        merchant_customer_id: 'MIDs',
        passengers: [
          { first_name: 'Randi',
            surname: 'Smith',
            surname_prefix: 'S',
            title: 'Mr' },
          { first_name: 'Julia',
            surname: 'Smith',
            surname_prefix: 'S',
            title: 'Mrs' }
        ],
        flight_legs: [
          { airline_class: 'ZZ',
            arrival_airport: 'BDL',
            arrival_time: '0520',
            carrier_code: 'SA',
            conjunction_ticket: 'ct-12',
            coupon_number: '1',
            date: '20190810',
            departure_time: '1220',
            endorsement_or_restriction: 'no',
            exchange_ticket: 'no',
            fare: '20000',
            fare_basis: 'fareBasis',
            fee: '12',
            flight_number: '1',
            number: 596,
            origin_airport: 'RDU',
            passenger_class: 'coach',
            stopover_code: 'permitted',
            taxes: '700' },
          { arrival_airport: 'RDU',
            origin_airport: 'BDL',
            date: '20190817',
            carrier_code: 'SA',
            number: 597,
            airline_class: 'ZZ' }
        ]
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase_with_insufficient_airline_data
    options = @options.merge(
      airline_data: {
        flight_date: '20190810',
        passenger_name: 'Randi Smith'
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'PARAMETER_NOT_FOUND_IN_REQUEST', response.message
    property_names = response.params['errors'].collect { |e| e['propertyName'] }
    assert property_names.include? 'order.additionalInput.airlineData.code'
    assert property_names.include? 'order.additionalInput.airlineData.name'
  end

  def test_successful_purchase_with_lodging_data
    options = @options.merge(
      lodging_data: {
        charges: [
          { charge_amount: '1000',
            charge_amount_currency_code: 'USD',
            charge_type: 'giftshop' }
        ],
        check_in_date: '20211223',
        check_out_date: '20211227',
        folio_number: 'randAssortmentofChars',
        is_confirmed_reservation: 'true',
        is_facility_fire_safety_conform: 'true',
        is_no_show: 'false',
        is_preference_smoking_room: 'false',
        number_of_adults: '2',
        number_of_nights: '1',
        number_of_rooms: '1',
        program_code: 'advancedDeposit',
        property_customer_service_phone_number: '5555555555',
        property_phone_number: '5555555555',
        renter_name: 'Guy',
        rooms: [
          { daily_room_rate: '25000',
            daily_room_rate_currency_code: 'USD',
            daily_room_tax_amount: '5',
            daily_room_tax_amount_currency_code: 'USD',
            number_of_nights_at_room_rate: '1',
            room_location: 'Courtyard',
            type_of_bed: 'Queen',
            type_of_room: 'Walled' }
        ]
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_very_long_name
    credit_card = credit_card('4567350000427977', { first_name: 'thisisaverylongfirstname' })

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_blank_name
    credit_card = credit_card('4567350000427977', { first_name: nil, last_name: nil })

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_pre_authorization_flag
    response = @gateway.purchase(@accepted_amount, @credit_card, @options.merge(pre_authorization: true))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_truncated_address
    response = @gateway.purchase(@amount, @credit_card, @long_address)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@rejected_amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Not authorised', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_authorize_with_optional_idempotency_key_header
    response = @gateway.authorize(@accepted_amount, @credit_card, @options.merge(idempotency_key: 'test123'))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Not authorised', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
    assert_equal 99, capture.params['payment']['paymentOutput']['amountOfMoney']['amount']
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '123', @options)
    assert_failure response
    assert_match %r{UNKNOWN_PAYMENT_ID}, response.message
  end

  # Because payments are not fully authorized immediately, refunds can only be
  # tested on older transactions (~24hrs old should be fine)
  #
  # def test_successful_refund
  #   txn = REPLACE WITH PREVIOUS TRANSACTION AUTHORIZATION
  #
  #   assert refund = @gateway.refund(@accepted_amount, txn)
  #   assert_success refund
  #   assert_equal 'Succeeded', refund.message
  # end
  #
  # def test_partial_refund
  #   txn = REPLACE WITH PREVIOUS TRANSACTION AUTHORIZATION
  #
  #   assert refund = @gateway.refund(@amount-1, REPLACE WITH PREVIOUS TRANSACTION AUTHORIZATION)
  #   assert_success refund
  # end

  def test_failed_refund
    response = @gateway.refund(@amount, '123')
    assert_failure response
    assert_match %r{UNKNOWN_PAYMENT_ID}, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
    assert_match %r{UNKNOWN_PAYMENT_ID}, response.message
  end

  def test_failed_repeat_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message

    assert repeat_void = @gateway.void(auth.authorization)
    assert_failure repeat_void
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Not authorised', response.message
  end

  def test_invalid_login
    gateway = GlobalCollectGateway.new(merchant_id: '', api_key_id: '', secret_api_key: '')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{MISSING_OR_INVALID_AUTHORIZATION}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:secret_api_key], transcript)
  end

  def test_successful_preprod_auth_and_capture
    options = @preprod_options.merge(requires_approval: true)
    auth = @gateway_preprod.authorize(@accepted_amount, @preprod_card, options)
    assert_success auth

    assert capture = @gateway_preprod.capture(@amount, auth.authorization, options)
    assert_success capture
    assert_equal 'CAPTURE_REQUESTED', capture.params['payment']['status']
  end

  def test_successful_preprod_purchase
    options = @preprod_options.merge(requires_approval: false)
    assert purchase = @gateway_preprod.purchase(@accepted_amount, @preprod_card, options)
    assert_success purchase
  end

  def test_successful_preprod_void
    options = @preprod_options.merge(requires_approval: true)
    auth = @gateway_preprod.authorize(@amount, @preprod_card, options)
    assert_success auth

    assert void = @gateway_preprod.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end
end
