require 'test_helper'

class RemoteAuthorizeNetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(fixtures(:authorize_net))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @check = check
    @declined_card = credit_card('400030001111222')
    @apple_pay_payment_token = apple_pay_payment_token

    @options = {
      order_id: '1',
      duplicate_window: 0,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, duplicate_window: 0)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
    assert_equal 'incorrect_number', response.error_code
  end

  def test_successful_purchase_with_utf_character
    card = credit_card('4000100011112224', last_name: 'Wåhlin')
    response = @gateway.purchase(@amount, card, @options)
    assert_success response
    assert_match %r{This transaction has been approved}, response.message
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_no_data
    no_data_credit_card = ActiveMerchant::Billing::CreditCard.new
    response = @gateway.purchase(@amount, no_data_credit_card, @options)
    assert_failure response
    assert_match %r{invalid}, response.message
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
    assert_equal 'expired_card', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_purchase_with_disable_partial_authorize
    purchase = @gateway.purchase(46225, @credit_card, @options.merge(disable_partial_auth: true))
    assert_success purchase
  end

  def test_successful_authorize_with_email_and_ip
    options = @options.merge({email: 'hello@example.com', ip: '127.0.0.1'})
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
  end

  def test_card_present_authorize_and_capture_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    assert_equal 'This transaction has been approved', capture.message
  end

  def test_successful_echeck_authorization
    response = @gateway.authorize(@amount, @check, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_echeck_authorization
    response = @gateway.authorize(@amount, check(routing_number: "121042883"), @options)
    assert_failure response
    assert_equal 'The ABA code is invalid', response.message
    assert response.authorization
  end

  def test_successful_apple_pay_authorization
    response = @gateway.authorize(5, @apple_pay_payment_token, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_apple_pay_purchase
    response = @gateway.purchase(5, @apple_pay_payment_token, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_apple_pay_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_successful_apple_pay_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end


  def test_failed_apple_pay_authorization
    response = @gateway.authorize(@amount, apple_pay_payment_token(payment_data: {data: 'garbage'}), @options)
    assert_failure response
    assert_equal 'There was an error processing the payment data', response.message
    assert_equal 'processing_error', response.error_code
  end

  def test_failed_apple_pay_purchase
    response = @gateway.purchase(@amount, apple_pay_payment_token(payment_data: {data: 'garbage'}), @options)
    assert_failure response
    assert_equal 'There was an error processing the payment data', response.message
    assert_equal 'processing_error', response.error_code
  end

  def test_card_present_purchase_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    response = @gateway.purchase(@amount, track_credit_card, @options)
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_moto_retail_type
    @credit_card.manual_entry = true
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_successful_authorization_with_moto_retail_type
    @credit_card.manual_entry = true
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    bogus_card = credit_card('4424222222222222')
    response = @gateway.verify(bogus_card, @options)
    assert_failure response
    assert_match %r{The credit card number is invalid}, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert response.authorization
    assert_equal "Successful", response.message
    assert_equal "1", response.params["message_code"]
  end

  def test_failed_store
    assert response = @gateway.store(credit_card("141241"))
    assert_failure response
    assert_equal "The field length is invalid for Card Number", response.message
    assert_equal "15", response.params["message_code"]
  end

  def test_successful_purchase_using_stored_card
    response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal "This transaction has been approved.", response.message
  end

  def test_failed_purchase_using_stored_card
    response = @gateway.store(@declined_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_failure response
    assert_equal "The credit card number is invalid.", response.message
    assert_equal "incorrect_number", response.error_code
    assert_equal "27", response.params["message_code"]
    assert_equal "6", response.params["response_reason_code"]
    assert_match /but street address not verified/, response.avs_result["message"]
  end

  def test_successful_authorize_and_capture_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth
    assert_equal "This transaction has been approved.", auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "This transaction has been approved.", capture.message
  end

  def test_failed_authorize_using_stored_card
    response = @gateway.store(@declined_card)
    assert_success response

    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_failure response

    assert_equal "The credit card number is invalid.", response.message
    assert_equal "incorrect_number", response.error_code
    assert_equal "27", response.params["message_code"]
    assert_equal "6", response.params["response_reason_code"]
    assert_match /but street address not verified/, response.avs_result["message"]
  end

  def test_failed_capture_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    capture = @gateway.capture(@amount + 4000, auth.authorization)
    assert_failure capture
    assert_match /The amount requested for settlement cannot be greater/, capture.message
  end

  def test_faux_successful_refund_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_failure refund
    assert_match /does not meet the criteria for issuing a credit/, refund.message, "Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise."
  end

  def test_failed_refund_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase

    unknown_authorization = "2235494048#XXXX2224#cim_purchase"
    refund = @gateway.refund(@amount, unknown_authorization, @options)
    assert_failure refund
    assert_equal "The record cannot be found", refund.message
  end

  def test_successful_void_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "This transaction has been approved.", void.message
  end

  def test_failed_void_using_stored_card
    store = @gateway.store(@credit_card)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    void = @gateway.void(auth.authorization)
    assert_success void

    another_void = @gateway.void(auth.authorization)
    assert_failure another_void
    assert_equal "This transaction has already been voided.", another_void.message
  end

  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response

    assert_equal %w(
      account_number
      action
      authorization_code
      avs_result_code
      card_code
      cardholder_authentication_code
      response_code
      response_reason_code
      response_reason_text
      test_request
      transaction_id
    ), response.params.keys.sort

    assert_equal "User authentication failed due to invalid authentication values", response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(20, '23124#1234')
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

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = 'A1000000'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  ensure
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = nil
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
    assert response.authorization
  end

  def test_bad_currency
    response = @gateway.purchase(@amount, @credit_card, currency: "XYZ")
    assert_failure response
    assert_equal 'The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn\'t have an exchange rate', response.message
  end

  def test_usd_currency
    @options[:currency] = "USD"
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
  end

  def test_dump_transcript
    # dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_successful_authorize_and_capture_with_network_tokenization
    credit_card = network_tokenization_credit_card('4000100011112224',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil
    )
    auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_network_tokenization_transcript_scrubbing
    credit_card = network_tokenization_credit_card('4111111111111111',
      :brand              => 'visa',
      :eci                => "05",
      :payment_cryptogram => "EHuWW9PiBkWvqE5juRwDzAUFBAk="
    )

    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_purchase_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  private

  def apple_pay_payment_token(options = {})
    # The payment_data field below is sourced from: http://developer.authorize.net/api/reference/#apple-pay-transactions
    # Other fields are motivated by https://developer.apple.com/library/ios/documentation/PassKit/Reference/PKPaymentToken_Ref/index.html
    defaults = {
      payment_data: {
        'data' => 'BDPNWStMmGewQUWGg4o7E/j+1cq1T78qyU84b67itjcYI8wPYAOhshjhZPrqdUr4XwPMbj4zcGMdy++1H2VkPOY+BOMF25ub19cX4nCvkXUUOTjDllB1TgSr8JHZxgp9rCgsSUgbBgKf60XKutXf6aj/o8ZIbKnrKQ8Sh0ouLAKloUMn+vPu4+A7WKrqrauz9JvOQp6vhIq+HKjUcUNCITPyFhmOEtq+H+w0vRa1CE6WhFBNnCHqzzWKckB/0nqLZRTYbF0p+vyBiVaWHeghERfHxRtbzpeczRPPuFsfpHVs48oPLC/k/1MNd47kz/pHDcR/Dy6aUM+lNfoily/QJN+tS3m0HfOtISAPqOmXemvr6xJCjCZlCuw0C9mXz/obHpofuIES8r9cqGGsUAPDpw7g642m4PzwKF+HBuYUneWDBNSD2u6jbAG3',
        'version' => 'EC_v1',
        'header' => {
          'applicationData' => '94ee059335e587e501cc4bf90613e0814f00a7b08bc7c648fd865a2af6a22cc2',
          'transactionId' => 'c1caf5ae72f0039a82bad92b828363734f85bf2f9cadf193d1bad9ddcb60a795',
          'ephemeralPublicKey' => 'MIIBSzCCAQMGByqGSM49AgEwgfcCAQEwLAYHKoZIzj0BAQIhAP////8AAAABAAAAAAAAAAAAAAAA////////////////MFsEIP////8AAAABAAAAAAAAAAAAAAAA///////////////8BCBaxjXYqjqT57PrvVV2mIa8ZR0GsMxTsPY7zjw+J9JgSwMVAMSdNgiG5wSTamZ44ROdJreBn36QBEEEaxfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54WK84zV2sxXs7LtkBoN79R9QIhAP////8AAAAA//////////+85vqtpxeehPO5ysL8YyVRAgEBA0IABGm+gsl0PZFT/kDdUSkxwyfo8JpwTQQzBm9lJJnmTl4DGUvAD4GseGj/pshBZ0K3TeuqDt/tDLbE+8/m0yCmoxw=',
          'publicKeyHash' => '/bb9CNC36uBheHFPbmohB7Oo1OsX2J+kJqv48zOVViQ='
        },
        'signature' => 'MIIDQgYJKoZIhvcNAQcCoIIDMzCCAy8CAQExCzAJBgUrDgMCGgUAMAsGCSqGSIb3DQEHAaCCAiswggInMIIBlKADAgECAhBcl+Pf3+U4pk13nVD9nwQQMAkGBSsOAwIdBQAwJzElMCMGA1UEAx4cAGMAaABtAGEAaQBAAHYAaQBzAGEALgBjAG8AbTAeFw0xNDAxMDEwNjAwMDBaFw0yNDAxMDEwNjAwMDBaMCcxJTAjBgNVBAMeHABjAGgAbQBhAGkAQAB2AGkAcwBhAC4AYwBvAG0wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBANC8+kgtgmvWF1OzjgDNrjTEBRuo/5MKvlM146pAf7Gx41blE9w4fIXJAD7FfO7QKjIXYNt39rLyy7xDwb/5IkZM60TZ2iI1pj55Uc8fd4fzOpk3ftZaQGXNLYptG1d9V7IS82Oup9MMo1BPVrXTPHNcsM99EPUnPqdbeGc87m0rAgMBAAGjXDBaMFgGA1UdAQRRME+AEHZWPrWtJd7YZ431hCg7YFShKTAnMSUwIwYDVQQDHhwAYwBoAG0AYQBpAEAAdgBpAHMAYQAuAGMAbwBtghBcl+Pf3+U4pk13nVD9nwQQMAkGBSsOAwIdBQADgYEAbUKYCkuIKS9QQ2mFcMYREIm2l+Xg8/JXv+GBVQJkOKoscY4iNDFA/bQlogf9LLU84THwNRnsvV3Prv7RTY81gq0dtC8zYcAaAkCHII3yqMnJ4AOu6EOW9kJk232gSE7WlCtHbfLSKfuSgQX8KXQYuZLk2Rr63N8ApXsXwBL3cJ0xgeAwgd0CAQEwOzAnMSUwIwYDVQQDHhwAYwBoAG0AYQBpAEAAdgBpAHMAYQAuAGMAbwBtAhBcl+Pf3+U4pk13nVD9nwQQMAkGBSsOAwIaBQAwDQYJKoZIhvcNAQEBBQAEgYBaK3ElOstbH8WooseDABf+Jg/129JcIawm7c6Vxn7ZasNbAq3tAt8Pty+uQCgssXqZkLA7kz2GzMolNtv9wYmu9Ujwar1PHYS+B/oGnoz591wjagXWRz0nMo5y3O1KzX0d8CRHAVa88SrV1a5JIiRev3oStIqwv5xuZldag6Tr8w=='
      },
      payment_instrument_name: "SomeBank Points Card",
      payment_network: "MasterCard",
      transaction_identifier: "uniqueidentifier123"
    }.update(options)

    ActiveMerchant::Billing::ApplePayPaymentToken.new(defaults[:payment_data],
      payment_instrument_name: defaults[:payment_instrument_name],
      payment_network: defaults[:payment_network],
      transaction_identifier: defaults[:transaction_identifier]
    )
  end
end
