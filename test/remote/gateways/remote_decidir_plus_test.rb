require 'test_helper'
require 'securerandom'

class RemoteDecidirPlusTest < Test::Unit::TestCase
  def setup
    @gateway = DecidirPlusGateway.new(fixtures(:decidir_plus))

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
      send_to_cs: false,
      channel: 'Web',
      dispatch_method: 'Store Pick Up',
      csmdds: [
        {
          code: 17,
          description: 'Campo MDD17'
        }
      ]
    }
  end

  def test_successful_purchase
    assert response = @gateway.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway.purchase(@amount, payment_reference, @options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase
    assert @gateway.store(@credit_card)

    response = @gateway.purchase(@amount, '', @options)
    assert_failure response
    assert_equal 'invalid_param: token', response.message
  end

  def test_successful_refund
    response = @gateway.store(@credit_card)

    purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal 'approved', purchase.message

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_partial_refund
    assert response = @gateway.store(@credit_card)

    purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'active', response.message
    assert_equal @credit_card.number[0..5], response.authorization.split('|')[1]
  end

  def test_successful_purchase_with_options
    options = @options.merge(sub_payments: @sub_payments)

    assert response = @gateway.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_fraud_detection
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway.purchase(@amount, payment_reference, options)
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
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:public_key], transcript)
    assert_scrubbed(@gateway.options[:private_key], transcript)
  end
end
