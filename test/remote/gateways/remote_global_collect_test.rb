require 'test_helper'

class RemoteGlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))

    @amount = 100
    @credit_card = credit_card('4567350000427977')
    @declined_card = credit_card('5424180279791732')
    @accepted_amount = 4005
    @rejected_amount = 2997
    @options = {
      email: 'example@example.com',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@accepted_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_fraud_fields
    options = @options.merge(
      fraud_fields:
      {
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

  def test_successful_purchase_with_airline_data
    options = @options.merge(
      airline_data: {
        code: 111,
        name: 'Spreedly Airlines',
        flight_date: '20190810',
        passenger_name: 'Randi Smith',
        flight_legs: [
          { arrival_airport: 'BDL',
            origin_airport: 'RDU',
            date: '20190810',
            carrier_code: 'SA',
            number: 596,
            airline_class: 'ZZ'},
          { arrival_airport: 'RDU',
            origin_airport: 'BDL',
            date: '20190817',
            carrier_code: 'SA',
            number: 597,
            airline_class: 'ZZ'}
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

  def test_successful_purchase_with_very_long_name
    credit_card = credit_card('4567350000427977', { first_name: 'thisisaverylongfirstname'})

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_blank_name
    credit_card = credit_card('4567350000427977', { first_name: nil, last_name: nil})

    response = @gateway.purchase(@amount, credit_card, @options)
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
end
