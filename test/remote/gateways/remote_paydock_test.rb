require 'test_helper'

class RemotePaydockTest < Test::Unit::TestCase
  def setup
    @gateway = PaydockGateway.new(fixtures(:paydock))

    @amount = rand(1..50) * 200 # create test amount between 2 and 100 dollars

    # PinPayments test cards, may not work with other gateways
    @visa = {
        success: credit_card('4200000000000000'),
        decline: credit_card('4100000000000001'),
        no_funds: credit_card('4000000000000002'),
        invalid_cvv: credit_card('4900000000000003'),
        invalid_card: credit_card('4800000000000004'),
        processing_error: credit_card('4700000000000005'),
        susptected_fraud: credit_card('4600000000000006'),
        unknown_error: credit_card('4400000000000099')
    }
    @mastercard = {
        success: credit_card('5520000000000000'),
        decline: credit_card('5560000000000001'),
        no_funds: credit_card('5510000000000002'),
        invalid_cvv: credit_card('5550000000000003'),
        invalid_card: credit_card('5500000000000004'),
        processing_error: credit_card('5590000000000005'),
        susptected_fraud: credit_card('5540000000000006'),
        unknown_error: credit_card('5530000000000099')
    }

    @amex = {
        success: credit_card('372000000000000',{verification_value:1234}),
        decline: credit_card('371000000000001',{verification_value:1234}),
        no_funds: credit_card('370000000000002',{verification_value:1234}),
        invalid_cvv: credit_card('379000000000003',{verification_value:1234}),
        invalid_card: credit_card('378000000000004',{verification_value:1234}),
        processing_error: credit_card('377000000000005',{verification_value:1234}),
        susptected_fraud: credit_card('376000000000006',{verification_value:1234}),
        unknown_error: credit_card('374000000000099',{verification_value:1234})
    }

    # switch between visa, mastercard or amex cards
    case rand(1..2)
    when 2
      @card = @mastercard
    when 3
      @card = @amex
    else
      @card = @visa
    end

    @card_success = @card[:success]
    @card_decline = @card[:decline]

    @options = {
      description: 'Store Purchase',
      customer: {
          email: 'activemerchant@paydock.com'
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @card_success, @options)
    assert_success response
    assert_equal 201, response.params['status']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      reference: 'TestReference',
      customer: {
          first_name: 'Joe',
          last_name: 'Blow',
          email: "joe@example.com"
      }
    }

    response = @gateway.purchase(@amount, @card_success, options)

    assert_success response
    assert_equal 201, response.params['status']
    assert_match 'Succeeded', response.message
    assert_equal 'TestReference', response.params['resource']['data']['reference']
    assert_equal 'complete', response.params['resource']['data']['status']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @card_decline, @options)
    assert_failure response
    assert_equal 400, response.params['status']
    assert_equal 'card_declined', response.params['error']['details'][0]['gateway_specific_code']
    assert_equal 'failed', response.params['resource']['data']['status']
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @card_success, @options)
    assert_success auth
    assert_equal 'pending', auth.params['resource']['data']['status']

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'complete', capture.params['resource']['data']['status']
    assert_equal nil, capture.params['error']
  end

  def test_successful_store
    auth = @gateway.store(@card_success, @options)
    assert_success auth
  end

  def test_successful_store_without_cvv
    @card_success.verification_value = nil
    auth = @gateway.store(@card_success, @options)
    assert_failure auth
  end

  def test_failed_store
    auth = @gateway.store(ActiveMerchant::Billing::CreditCard.new({}), @options)
    assert_failure auth
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @card_decline, @options)
    assert_failure response
    assert_equal 400, response.params['status']
    assert_equal 'card_declined', response.params['error']['details'][0]['gateway_specific_code']
    assert_equal 'failed', response.params['resource']['data']['status']
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Invalid charge_id in authorization for capture', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @card_success, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 200, refund.params['status']
    assert_equal 'refund_requested', refund.params['resource']['data']['status']
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @card_success, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount / 2, purchase.authorization)
    assert_success refund
    assert_equal 200, refund.params['status']
    assert_equal 'refund_requested', refund.params['resource']['data']['status']
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @card_success, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount * 2, purchase.authorization)
    assert_failure refund
    assert_equal 400, refund.params['status']
  end

  def test_invalid_login
    gateway = PaydockGateway.new(login: '', password: '')

    response = gateway.purchase(@amount, @card_success, @options)
    assert_failure response
    assert_equal 403, response.params['status']
    assert_match %r{Access forbidden}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @card_success, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed('\"' + @card_success.number + '\"', transcript)
    assert_scrubbed('\"' + @card_success.verification_value  + '\"', transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
