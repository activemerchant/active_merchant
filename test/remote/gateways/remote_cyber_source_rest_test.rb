require 'test_helper'

class RemoteCyberSourceRestTest < Test::Unit::TestCase
  def setup
    @gateway = CyberSourceRestGateway.new(fixtures(:cybersource_rest))
    @amount = 10221
    @card_without_funds = credit_card('42423482938483873')
    @visa_card = credit_card('4111111111111111',
      verification_value: '987',
      month: 12,
      year: 2031)

    @billing_address = {
      name:     'John Doe',
      address1: '1 Market St',
      city:     'san francisco',
      state:    'CA',
      zip:      '94105',
      country:  'US',
      phone:    '4158880000'
    }

    @options = {
      order_id: generate_unique_id,
      currency: 'USD',
      email: 'test@cybs.com'
    }
  end

  def test_handle_credentials_error
    gateway = CyberSourceRestGateway.new({ merchant_id: 'abc123', public_key: 'abc456', private_key: 'def789' })
    response = gateway.authorize(@amount, @visa_card, @options)

    assert_equal('Authentication Failed', response.message)
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_successful_authorize_with_billing_address
    @options[:billing_address] = @billing_address
    response = @gateway.authorize(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_failure_authorize_with_declined_credit_card
    response = @gateway.authorize(@amount, @card_without_funds, @options)

    assert_failure response
    assert_match %r{Invalid account}, response.message
    assert_equal 'INVALID_ACCOUNT', response.error_code
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response = @gateway.refund(@amount, purchase.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert response.params['_links']['void'].present?
  end

  def test_failure_refund
    purchase = @gateway.purchase(@amount, @card_without_funds, @options)
    response = @gateway.refund(@amount, purchase.authorization, @options)

    assert_failure response
    assert response.test?
    assert_match %r{Declined - One or more fields in the request contains invalid data}, response.params['message']
    assert_equal 'INVALID_DATA', response.params['reason']
  end

  def test_successful_partial_refund
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response = @gateway.refund(@amount / 2, purchase.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert response.params['_links']['void'].present?
  end

  def test_successful_repeat_refund_transaction
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response1 = @gateway.refund(@amount, purchase.authorization, @options)

    assert_success response1
    assert response1.test?
    assert_equal 'PENDING', response1.message
    assert response1.params['id'].present?
    assert response1.params['_links']['void']

    response2 = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success response2
    assert response2.test?
    assert_equal 'PENDING', response2.message
    assert response2.params['id'].present?
    assert response2.params['_links']['void']

    assert_not_equal response1.params['_links']['void'], response2.params['_links']['void']
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert_nil response.params['_links']['capture']
  end

  def test_failure_credit
    response = @gateway.credit(@amount, @card_without_funds, @options)

    assert_failure response
    assert response.test?
    assert_match %r{Decline - Invalid account number}, response.message
    assert_equal 'INVALID_ACCOUNT', response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @visa_card, @options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@visa_card.number, transcript)
    assert_scrubbed(@visa_card.verification_value, transcript)
  end
end
