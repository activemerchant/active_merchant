require 'test_helper'

class RemoteEbanxTest < Test::Unit::TestCase
  def setup
    @gateway = EbanxGateway.new(fixtures(:ebanx))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('5102026827345142')
    @options = {
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Maracanaú',
        state: 'CE',
        zip: '61919-230',
        country: 'BR',
        phone_number: '8522847035'
      }),
      order_id: generate_unique_id,
      document: "853.513.468-93"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge({
      order_id: generate_unique_id,
      ip: "127.0.0.1",
      email: "joe@example.com",
      birth_date: "10/11/1980",
      person_type: 'personal'
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_as_brazil_business_with_responsible_fields
    options = @options.update(document: "32593371000110",
                              person_type: 'business',
                              responsible_name: 'Business Person',
                              responsible_document: '32593371000111',
                              responsible_birth_date: "1/11/1975")

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_as_colombian
    options = @options.merge({
      order_id: generate_unique_id,
      ip: "127.0.0.1",
      email: "jose@example.com.co",
      birth_date: "10/11/1980",
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Medellín',
        state: 'AN',
        zip: '29269',
        country: 'CO',
        phone_number: '8522847035'
      })
    })

    response = @gateway.purchase(500, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Sandbox - Test credit card, transaction declined reason insufficientFunds', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Accepted', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Sandbox - Test credit card, transaction declined reason insufficientFunds', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge({description: "full refund"})
    assert refund = @gateway.refund(@amount, purchase.authorization, refund_options)
    assert_success refund
    assert_equal 'Accepted', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge(description: "refund due to returned item")
    assert refund = @gateway.refund(@amount-1, purchase.authorization, refund_options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_match('Parameter hash not informed', response.message)
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Accepted', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Parameter hash not informed', response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message
  end

  def test_successful_store_and_purchase_as_brazil_business
    options = @options.update(document: "32593371000110",
                              person_type: 'business',
                              responsible_name: 'Business Person',
                              responsible_document: '32593371000111',
                              responsible_birth_date: "1/11/1975")

    store = @gateway.store(@credit_card, options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message
  end

  def test_failed_purchase_with_stored_card
    store = @gateway.store(@declined_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_failure purchase
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Accepted}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Accepted}, response.message
  end

  def test_invalid_login
    gateway = EbanxGateway.new(integration_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Field integration_key is required}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:integration_key], transcript)
  end

end
