require 'test_helper'

class RemoteDatatransTest < Test::Unit::TestCase
  def setup
    @gateway = DatatransGateway.new(fixtures(:datatrans))

    @amount = 756
    @credit_card = credit_card('4242424242424242', verification_value: '123', first_name: 'John', last_name: 'Smith', month: 6, year: Time.now.year + 1)
    @bad_amount = 100000 # anything grather than 500 EUR
    @credit_card_frictionless = credit_card('4000001000000018', verification_value: '123', first_name: 'John', last_name: 'Smith', month: 6, year: 2025)

    @options = {
      order_id: SecureRandom.random_number(1000000000).to_s,
      description: 'An authorize',
      email: 'john.smith@test.com'
    }

    @three_d_secure = {
      three_d_secure: {
        eci: '05',
        cavv: '3q2+78r+ur7erb7vyv66vv8=',
        cavv_algorithm: '1',
        ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
        enrolled: 'Y',
        authentication_response_status: 'Y',
        directory_response_status: 'Y',
        version: '2',
        three_ds_server_trans_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      }
    }

    @billing_address = address
    @no_country_billing_address = address(country: nil)

    @google_pay_card = network_tokenization_credit_card(
      '4900000000000094',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '06',
      year: '2025',
      source: :google_pay,
      verification_value: 569
    )

    @apple_pay_card = network_tokenization_credit_card(
      '4900000000000094',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '06',
      year: '2025',
      source: :apple_pay,
      verification_value: 569
    )

    @nt_credit_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '07',
      source: :network_token,
      verification_value: '737',
      brand: 'visa'
    )
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_include response.params, 'transactionId'
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_include response.params, 'transactionId'
  end

  def test_failed_authorize
    # the bad amount currently is only setle to EUR currency
    response = @gateway.purchase(@bad_amount, @credit_card, @options.merge({ currency: 'EUR' }))
    assert_failure response
    assert_equal response.error_code, 'BLOCKED_CARD'
    assert_equal response.message, 'card blocked'
  end

  def test_failed_authorize_invalid_currency
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ currency: 'DKK' }))
    assert_failure response
    assert_equal response.error_code, 'INVALID_PROPERTY'
    assert_equal response.message, 'authorize.currency'
  end

  def test_successful_capture
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    response = @gateway.capture(@amount, authorize_response.authorization, @options)
    assert_success response
    assert_equal response.authorization, nil
  end

  def test_successful_refund
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    response = @gateway.refund(@amount, purchase_response.authorization, @options)
    assert_success response
    assert_include response.params, 'transactionId'
  end

  def test_successful_capture_with_less_authorized_amount_and_refund
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(@amount - 100, authorize_response.authorization, @options)
    assert_success capture_response

    response = @gateway.refund(@amount - 200, authorize_response.authorization, @options)
    assert_success response
  end

  def test_failed_partial_capture_already_captured
    authorize_response = @gateway.authorize(2500, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(100, authorize_response.authorization, @options)
    assert_success capture_response

    response = @gateway.capture(100, authorize_response.authorization, @options)
    assert_failure response
    assert_equal response.error_code, 'INVALID_TRANSACTION_STATUS'
    assert_equal response.message, 'already settled'
  end

  def test_failed_partial_capture_refund_refund_exceed_captured
    authorize_response = @gateway.authorize(200, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(100, authorize_response.authorization, @options)
    assert_success capture_response

    response = @gateway.refund(200, authorize_response.authorization, @options)
    assert_failure response
    assert_equal response.error_code, 'INVALID_PROPERTY'
    assert_equal response.message, 'credit.amount'
  end

  def test_failed_consecutive_partial_refund_when_total_exceed_amount
    purchase_response = @gateway.purchase(700, @credit_card, @options)

    assert_success purchase_response

    refund_response_1 = @gateway.refund(200, purchase_response.authorization, @options)
    assert_success refund_response_1

    refund_response_2 = @gateway.refund(200, purchase_response.authorization, @options)
    assert_success refund_response_2

    refund_response_3 = @gateway.refund(200, purchase_response.authorization, @options)
    assert_success refund_response_3

    refund_response_4 = @gateway.refund(200, purchase_response.authorization, @options)
    assert_failure refund_response_4
    assert_equal refund_response_4.error_code, 'INVALID_PROPERTY'
    assert_equal refund_response_4.message, 'credit.amount'
  end

  def test_failed_refund_not_settle_transaction
    purchase_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success purchase_response

    response = @gateway.refund(@amount, purchase_response.authorization, @options)
    assert_failure response
    assert_equal response.error_code, 'INVALID_TRANSACTION_STATUS'
    assert_equal response.message, 'the transaction cannot be credited'
  end

  def test_successful_void
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    response = @gateway.void(authorize_response.authorization, @options)
    assert_success response

    assert_equal response.authorization, nil
  end

  def test_succesful_store_transaction
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_include store.params, 'overview'
    assert_equal store.params['overview'], { 'total' => 1, 'successful' => 1, 'failed' => 0 }
    assert store.params['responses'].is_a?(Array)
    assert_include store.params['responses'][0], 'alias'
    assert_equal store.params['responses'][0]['maskedCC'], '424242xxxxxx4242'
    assert_include store.params['responses'][0], 'fingerprint'
  end

  def test_successful_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store

    unstore = @gateway.unstore(store.authorization, @options)
    assert_success unstore
    assert_equal unstore.params['response_code'], 204
  end

  def test_successful_store_purchase_unstore_flow
    store = @gateway.store(@credit_card, @options)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_include purchase.params, 'transactionId'

    # second purchase to validate multiple use token
    second_purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success second_purchase

    unstore = @gateway.unstore(store.authorization, @options)
    assert_success unstore

    # purchase after unstore to validate deletion
    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_failure response
    assert_equal response.error_code, 'INVALID_ALIAS'
    assert_equal response.message, 'authorize.card.alias'
  end

  def test_failed_void_because_captured_transaction
    omit("the transaction could take about 20  minutes to
          pass from settle to transmited, use a previos
          transaction acutually transmited and comment this
          omition")

    # this is a previos transmited transaction, if the test fail use another, check dashboard to confirm it.
    previous_authorization = '240417191339383491|339523493'
    response = @gateway.void(previous_authorization, @options)
    assert_failure response
    assert_equal 'Action denied : Wrong transaction status', response.message
  end

  def test_successful_verify
    verify_response = @gateway.verify(@credit_card, @options)
    assert_success verify_response
  end

  def test_failed_verify
    verify_response = @gateway.verify(@credit_card, @options.merge({ currency: 'DKK' }))
    assert_failure verify_response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  def test_successful_purchase_with_billing_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: @billing_address }))

    assert_success response
  end

  def test_successful_purchase_with_no_country_billing_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ billing_address: @no_country_billing_address }))

    assert_success response
  end

  def test_successful_purchase_with_network_token
    response = @gateway.purchase(@amount, @nt_credit_card, @options)

    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay_card, @options)

    assert_success response
  end

  def test_successful_authorize_with_google_pay
    response = @gateway.authorize(@amount, @google_pay_card, @options)
    assert_success response
  end

  def test_successful_void_with_google_pay
    authorize_response = @gateway.authorize(@amount, @google_pay_card, @options)
    assert_success authorize_response

    response = @gateway.void(authorize_response.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_with_3ds
    response = @gateway.purchase(@amount, @credit_card_frictionless, @options.merge(@three_d_secure))
    assert_success response
  end

  def test_failed_purchase_with_3ds
    @three_d_secure[:three_d_secure][:cavv] = '\/\/\/\/8='
    response = @gateway.purchase(@amount, @credit_card_frictionless, @options.merge(@three_d_secure))
    assert_failure response
    assert_equal response.error_code, 'INVALID_PROPERTY'
    assert_equal response.message, 'cavv format is invalid. make sure that the value is base64 encoded and has a proper length.'
  end
end
