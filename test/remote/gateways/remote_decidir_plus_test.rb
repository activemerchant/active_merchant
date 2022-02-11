require 'test_helper'
require 'securerandom'

class RemoteDecidirPlusTest < Test::Unit::TestCase
  def setup
    @gateway_purchase = DecidirPlusGateway.new(fixtures(:decidir_plus))
    @gateway_auth = DecidirPlusGateway.new(fixtures(:decidir_plus_preauth))

    @amount = 100
    @credit_card = credit_card('4484590159923090')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
    @sub_payments = [
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      },
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      }
    ]
    @fraud_detection = {
      send_to_cs: 'false',
      channel: 'Web',
      dispatch_method: 'Store Pick Up',
      csmdds: [
        {
          code: '17',
          description: 'Campo MDD17'
        }
      ]
    }
  end

  def test_successful_purchase
    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, @options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase
    assert @gateway_purchase.store(@credit_card)

    response = @gateway_purchase.purchase(@amount, '', @options)
    assert_failure response
    assert_equal 'invalid_param: token', response.message
  end

  def test_successful_authorize_and_capture
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_auth.store(@credit_card, options)
    payment_reference = response.authorization

    response = @gateway_auth.authorize(@amount, payment_reference, options)
    assert_success response

    assert capture_response = @gateway_auth.capture(@amount, response.authorization, options)
    assert_success capture_response
  end

  def test_successful_refund
    response = @gateway_purchase.store(@credit_card)

    purchase = @gateway_purchase.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal 'approved', purchase.message

    assert refund = @gateway_purchase.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_partial_refund
    assert response = @gateway_purchase.store(@credit_card)

    purchase = @gateway_purchase.purchase(@amount, response.authorization, @options)
    assert_success purchase

    assert refund = @gateway_purchase.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway_purchase.refund(@amount, '')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_void
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_auth.store(@credit_card, options)
    payment_reference = response.authorization

    response = @gateway_auth.authorize(@amount, payment_reference, options)
    assert_success response
    assert_equal 'pre_approved', response.message
    authorization = response.authorization

    assert void_response = @gateway_auth.void(authorization)
    assert_success void_response
  end

  def test_failed_void
    assert response = @gateway_auth.void('')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_verify
    assert response = @gateway_auth.verify(@credit_card, @options.merge(fraud_detection: @fraud_detection))
    assert_success response
    assert_equal 'active', response.message
  end

  def test_failed_verify
    assert response = @gateway_auth.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'rejected', response.message
  end

  def test_successful_store
    assert response = @gateway_purchase.store(@credit_card)
    assert_success response
    assert_equal 'active', response.message
    assert_equal @credit_card.number[0..5], response.authorization.split('|')[1]
  end

  def test_successful_unstore
    customer = {
      id: 'John',
      email: 'decidir@decidir.com'
    }

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, @options.merge({ customer: customer }))
    assert_success response

    assert_equal 'approved', response.message
    token_id = response.authorization

    assert unstore_response = @gateway_purchase.unstore(token_id)
    assert_success unstore_response
  end

  def test_successful_purchase_with_options
    options = @options.merge(sub_payments: @sub_payments)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_fraud_detection
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal({ 'status' => nil }, response.params['fraud_detection'])
  end

  def test_invalid_login
    gateway = DecidirPlusGateway.new(public_key: '12345', private_key: 'abcde')

    response = gateway.store(@credit_card, @options)
    assert_failure response
    assert_match %r{Invalid authentication credentials}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway_purchase) do
      @gateway_purchase.store(@credit_card, @options)
    end
    transcript = @gateway_purchase.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway_purchase.options[:public_key], transcript)
    assert_scrubbed(@gateway_purchase.options[:private_key], transcript)
  end
end
