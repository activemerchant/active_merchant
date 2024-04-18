require 'test_helper'

class RemoteDatatransTest < Test::Unit::TestCase
  def setup
    @gateway = DatatransGateway.new(fixtures(:datatrans))

    @amount = 756
    @credit_card = credit_card('4242424242424242', verification_value: '123', first_name: 'John', last_name: 'Smith', month: 0o6, year: 2025)
    @bad_amount = 100000 # anything grather than 500 EUR

    @options = {
      order_id: SecureRandom.random_number(1000000000).to_s,
      description: 'An authorize',
      email: 'john.smith@test.com'
    }

    @billing_address = address

    @execute_threed = {
      execute_threed: true,
      redirect_url: 'http://www.example.com/redirect',
      callback_url: 'http://www.example.com/callback',
      three_ds_2: {
        browser_info:  {
          width: 390,
          height: 400,
          depth: 24,
          timezone: 300,
          user_agent: 'Spreedly Agent',
          java: false,
          javascript: true,
          language: 'en-US',
          browser_size: '05',
          accept_header: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
      }
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
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
    assert_equal authorize_response.authorization, response.authorization
  end

  def test_successful_refund
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    response = @gateway.refund(@amount, purchase_response.authorization, @options)
    assert_success response
  end

  def test_successful_capture_with_less_authorized_amount_and_refund
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(@amount - 100, authorize_response.authorization, @options)
    assert_success capture_response
    assert_equal authorize_response.authorization, capture_response.authorization

    response = @gateway.refund(@amount - 200, capture_response.authorization, @options)
    assert_success response
  end

  def test_failed_partial_capture_already_captured
    authorize_response = @gateway.authorize(2500, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(100, authorize_response.authorization, @options)
    assert_success capture_response

    response = @gateway.capture(100, capture_response.authorization, @options)
    assert_failure response
    assert_equal response.error_code, 'INVALID_TRANSACTION_STATUS'
    assert_equal response.message, 'already settled'
  end

  def test_failed_partial_capture_refund_refund_exceed_captured
    authorize_response = @gateway.authorize(200, @credit_card, @options)
    assert_success authorize_response

    capture_response = @gateway.capture(100, authorize_response.authorization, @options)
    assert_success capture_response

    response = @gateway.refund(200, capture_response.authorization, @options)
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
end
