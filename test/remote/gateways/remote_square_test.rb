require 'test_helper'

class RemoteSquareTest < Test::Unit::TestCase
  def setup
    @gateway = SquareGateway.new(fixtures(:square))

    @amount = 200
    @refund_amount = 100

    @card_nonce = 'cnon:card-nonce-ok'
    @declined_card_nonce = 'cnon:card-nonce-declined'

    @options = {
      reason: 'Customer Canceled',
    }

    @customer = {
      given_name: 'John',
      family_name: 'Doe',
      company_name: 'John Doe Inc',
      email_address: 'john.doe@example.com',
      phone_number: '1231231234',
      address: {
        address_line_1: '123 Main St.',
        address_line_2: 'Apt 2A',
        address_line_3: 'Att John Doe',
        locality: 'Chicago',
        administrative_district_level_1: 'Illinois',
        administrative_district_level_2: 'United States',
        postal_code: '94103'
      }
    }

    @bad_customer = {
      given_name: 'John',
      family_name: 'Doe',
      company_name: 'John Doe Inc',
      email_address: 'john.doe@example.com',
      phone_number: '1231231234',
      address: {
        address_line_1: '123 Main St.',
        address_line_2: 'Apt 2A',
        address_line_3: 'Att John Doe',
        locality: 'Chicago',
        administrative_district_level_1: 'Illinois',
        country: 'United States',
        postal_code: '94103'
      }
    }
  end

  def test_successful_authorize
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)

    assert_success authorization
    assert_not_nil authorization.authorization
    assert_equal 'APPROVED', authorization.params['payment']['status']
    assert_equal @amount, authorization.params['payment']['amount_money']['amount']
    assert_equal @gateway.default_currency.downcase, authorization.params['payment']['amount_money']['currency'].downcase
  end

  def test_unsuccessful_authorize
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @declined_card_nonce, @options)

    assert_failure authorization
    assert_equal 'FAILED', authorization.params['payment']['status']
  end

  def test_successful_authorize_then_capture
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)

    assert_success authorization
    assert_equal 'APPROVED', authorization.params['payment']['status']

    assert capture = @gateway.capture(authorization.authorization)

    assert_success capture
    assert_equal 'COMPLETED', capture.params['payment']['status']
  end

  def test_successful_authorize_then_void
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert authorization = @gateway.authorize(@amount, @card_nonce, @options)

    assert_success authorization
    assert_equal 'APPROVED', authorization.params['payment']['status']

    assert void = @gateway.void(authorization.authorization, @options)

    assert_success void
    assert_equal 'CANCELED', void.params['payment']['status']
  end

  def test_successful_purchase
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert purchase = @gateway.purchase(@amount, @card_nonce, @options)

    assert_success purchase
    assert_equal @amount, purchase.params['payment']['amount_money']['amount']
    assert_equal @gateway.default_currency.downcase, purchase.params['payment']['amount_money']['currency'].downcase
    assert_equal 'COMPLETED', purchase.params['payment']['status']
  end

  def test_unsuccessful_purchase
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert purchase = @gateway.purchase(@amount, @declined_card_nonce, @options)

    assert_failure purchase
    assert_equal 'FAILED', purchase.params['payment']['status']
  end

  def test_successful_purchase_then_refund
    @options[:idempotency_key] = SecureRandom.hex(10)

    assert purchase = @gateway.purchase(@amount, @card_nonce, @options)

    assert_success purchase
    assert_equal 'COMPLETED', purchase.params['payment']['status']

    sleep 2

    @options[:idempotency_key] = SecureRandom.hex(10)
    assert refund = @gateway.refund(@refund_amount, purchase.authorization, @options)

    assert_success refund
    assert_equal @refund_amount, refund.params['refund']['amount_money']['amount']
    assert_equal @gateway.default_currency.downcase, refund.params['refund']['amount_money']['currency'].downcase
    assert_equal 'PENDING', refund.params['refund']['status']
  end

  def test_successful_store
    @options[:customer] = @customer

    assert store = @gateway.store(@card_nonce, @options)

    assert_success store
    assert_not_nil store.params['customer']['id']
    assert_equal @options[:customer][:given_name], store.params['customer']['given_name']
    assert_equal @options[:customer][:address].stringify_keys!, store.params['customer']['address']

    assert_not_nil store.params['card']['id']
  end

  def test_unsuccessful_store
    @options[:customer] = @bad_customer

    assert store = @gateway.store(@card_nonce, @options)
    assert_failure store
  end

  def test_successful_store_then_unstore
    @options[:customer] = @customer

    assert store = @gateway.store(@card_nonce, @options)

    assert_success store

    assert unstore = @gateway.unstore(store.params['customer']['id'], @options)

    assert_success unstore
    assert_empty unstore.params
  end

  def test_successful_store_then_update
    @options[:customer] = @customer

    assert store = @gateway.store(@card_nonce, @options)

    assert_equal @customer[:given_name], store.params['customer']['given_name']
    assert_equal @customer[:family_name], store.params['customer']['family_name']

    updated_customer = { customer: { given_name: 'Tom', family_name: 'Smith' } }
    assert update = @gateway.update_customer(store.params['customer']['id'], updated_customer)

    assert_equal 'Tom', update.params['customer']['given_name']
    assert_equal 'Smith', update.params['customer']['family_name']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @options[:idempotency_key] = SecureRandom.hex(10)
      @gateway.purchase(@amount, @card_nonce, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:access_token], transcript)
    assert_scrubbed(@card_nonce, transcript)
  end

end
