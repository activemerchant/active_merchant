require 'test_helper'
require "support/mercury_helper"

class RemoteMercuryTest < Test::Unit::TestCase
  include MercuryHelper

  # MercuryCert.Net Testing Guide https://developer.vantiv.com/docs/DOC-1358
  # Defines various special values for certain configurations and behaviors, such as
  #
  # Test Merchant IDs
  # Mercury U.S. EMV Chip Test Card Information; requires amounts under $10.99
  # Mercury U.S. Magnetic Stripe Test Card Information; requires amounts under $10.99 or between $60.00--$9,999.00
  #
  # Trigger Amounts
  #   Partial Trigger Amounts
  # Card | Partial Trigger | Amount | Returns Partial Approval Amount | Additional Comments
  # Visa $23.54 $20.00 CardLookup returns “FSA” for card usage
  # MasterCard $23.62 $20.00
  # Discover $23.07 $20.00
  # American Express $23.80 $20.00
  #
  #   All Test Cards
  # The below amount triggers may be used with any of the test cards.
  #  Trigger Amount Trigger Response
  # 20.01 Call AMEX, Call DISCOVER, Visa/MC CALL CENTER
  # 20.04 PIC UP
  # 20.08 Amex, Disc, MC: AP WITH ID
  # 20.12 Disc, Visa, MC: INVLD TRAN CODE
  # 20.13 INVLD AMOUNT
  # 20.19 Disc, Visa, MC: PLEASE RETRY
  # 20.54 INVLD EXP DATE
  # 20.55 INVLD PIN
  # 20.75 Disc, MC, Visa: MAX PIN TRIES; Debit Declines
  # 20.91 ISSUER UNAVAIL, Disc: CALL DISCOVER
  # 23.00 ISSUER UNAVAIL (Timeout)
  # 24.00 10 second delay—currently returns decline

  # MercuryPay test environment limits access to known 'not real' accounts
  MERCURY_PAY_VALID_VISA = "4003000123456781"
  MERCURY_PAY_VALID_MASTERCARD = "5499990123456781"
  MERCURY_PAY_VALID_AMEX = "373953244361001"
  MERCURY_PAY_VALID_DISCOVER = "6011000997235373"

  MERCURY_PAY_OTHER_CC = "4005550000000480"

  def setup
    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100

    @credit_card = credit_card(MERCURY_PAY_VALID_VISA)

    @options = {
      :order_id => "c111111111.1",
      :description => "ActiveMerchant"
    }
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate SQ',
        :zip => '30329'
      }
    )
    @full_options = @options_with_billing.merge(
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :customer => "Tim",
      :tax => "5"
    )

    close_batch
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = @gateway.capture(nil, response.authorization)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end

  def test_failed_authorize
    response = @gateway.authorize(1100, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_purchase_and_void
    response = @gateway.purchase(102, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_successful_purchase
    response = @gateway.purchase(50, @credit_card, @options)

    assert_success response
    assert_equal "0.50", response.params["purchase"]
  end

  def test_store
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert response.params.has_key?("record_no")
    assert response.params['record_no'] != ''
  end

  def test_credit
    response = @gateway.credit(50, @credit_card, @options)

    assert_success response
    assert_equal "0.50", response.params["purchase"], response.inspect
  end

  def test_failed_purchase
    response = @gateway.purchase(1100, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_avs_and_cvv_results
    response = @gateway.authorize(333, @credit_card, @options_with_billing)

    assert_success response
    assert_equal(
      {
        "code" => "Y",
        "postal_match" => "Y",
        "street_match" => "Y",
        "message" => "Street address and 5-digit postal code match."
      },
      response.avs_result
    )
    assert_equal({"code"=>"M", "message"=>"CVV matches"}, response.cvv_result)
  end

  def test_avs_and_cvv_results_with_track_data
    pend "between 5e83afa38f5fe74821c0f73e6622198b2f719ea9 and 2eff2e81be3489b852167ebd5e3dea46a68a3de2, seems MercuryPay is inconsistent in returning nil and P 'not processed' when request omits AVS/CVV with track_data"

    @credit_card = credit_card_with_track_data(MERCURY_PAY_VALID_VISA)
    response = @gateway.authorize(333, @credit_card, @options_with_billing)

    assert_success response
    assert_equal(
      {
        "code" => nil,
        "postal_match" => nil,
        "street_match" => nil,
        "message" => nil
      },
      response.avs_result
    )
    assert_equal({"code"=>'P', "message"=>'CVV not processed'}, response.cvv_result)
  end

  # Is this supposed to be testing capture-less-than-authorize, or allow_partial_auth?
  # MercuryPay test framework seems to not carry across pre-auth-partial-code to capture, so unclear whether this
  # gateway adapter should take responsibility for blocking over-authorized amounts
  def test_partial_capture
    # In pre-auth request, a VISA with 23.54 triggers partial approval, if allow_partial_auth: true, else DECLINES
    visa_partial_card = credit_card(MERCURY_PAY_OTHER_CC)
    response = @gateway.authorize(2354, visa_partial_card, @options)
    assert_failure response
    assert_equal "DECLINE", response.message

    response = @gateway.authorize(2354, visa_partial_card, @options.merge(allow_partial_auth: true))
    assert_success response
    assert_equal('20.00', response.params['authorize'])

    # VISA w/ 23.54 likely should trigger partial on `capture` but that seems not to be implemented by MercuryPay
    pend('MercuryPay pre-authed for 20.00, so this request ought to decline but test framework forgot') do
      capture = @gateway.capture(2100, response.authorization)
      assert_failure capture
    end

    capture = @gateway.capture(2000, response.authorization)
    assert_success capture

    reverse = @gateway.refund(2000, capture.authorization)
    assert_success reverse
  end

  def test_authorize_with_bad_expiration_date
    @credit_card.month = 13
    @credit_card.year = 2001
    response = @gateway.authorize(575, @credit_card, @options_with_billing)
    assert_failure response
    assert_equal "INVLD EXP DATE", response.message
  end

  def test_mastercard_authorize_and_capture_with_refund
    mc = credit_card(MERCURY_PAY_VALID_MASTERCARD) #, :brand => "master")

    response = @gateway.authorize(200, mc, @options)
    assert_success response
    assert_equal '2.00', response.params['authorize']

    capture = @gateway.capture(200, response.authorization)
    assert_success capture
    assert_equal '2.00', capture.params['authorize']

    refund = @gateway.refund(200, capture.authorization)
    assert_success refund
    assert_equal '2.00', refund.params['purchase']
    assert_equal 'Return', refund.params['tran_code']
  end

  def test_amex_authorize_and_capture_with_refund
    amex = credit_card(MERCURY_PAY_VALID_AMEX)#, :brand => "american_express", :verification_value => "1234")

    response = @gateway.authorize(201, amex, @options)
    assert_success response
    assert_equal '2.01', response.params['authorize']

    capture = @gateway.capture(201, response.authorization)
    assert_success capture
    assert_equal '2.01', capture.params['authorize']

    response = @gateway.refund(201, capture.authorization, @options)
    assert_success response
    assert_equal '2.01', response.params['purchase']
  end

  def test_discover_authorize_and_capture
    discover = credit_card(MERCURY_PAY_VALID_DISCOVER) #, :brand => "discover")

    response = @gateway.authorize(225, discover, @options_with_billing)
    assert_success response
    assert_equal '2.25', response.params['authorize']

    capture = @gateway.capture(225, response.authorization)
    assert_success capture
    assert_equal '2.25', capture.params['authorize']
  end

  def test_refund_after_batch_close
    purchase = @gateway.purchase(50, @credit_card, @options)
    assert_success purchase

    close_batch

    refund = @gateway.refund(50, purchase.authorization)
    assert_success refund
  end

  def test_authorize_and_capture_without_tokenization
    gateway = MercuryGateway.new(fixtures(:mercury_no_tokenization))
    close_batch(gateway)

    response = gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = gateway.capture(nil, response.authorization, :credit_card => @credit_card)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end
  
  def test_successful_authorize_and_capture_with_track_1_data
    @credit_card = credit_card_with_track_data(MERCURY_PAY_VALID_VISA)
    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = @gateway.capture(nil, response.authorization)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end

  def test_successful_authorize_and_capture_with_track_2_data
    @credit_card = credit_card_track_2(MERCURY_PAY_VALID_VISA)

    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    capture = @gateway.capture(nil, response.authorization)
    assert_success capture
    assert_equal '1.00', capture.params['authorize']
  end

  def test_authorize_and_void
    response = @gateway.authorize(100, @credit_card, @options)
    assert_success response
    assert_equal '1.00', response.params['authorize']

    void = @gateway.void(response.authorization)
    assert_success void
  end
end
