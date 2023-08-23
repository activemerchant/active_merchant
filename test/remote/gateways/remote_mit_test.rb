require 'test_helper'

class RemoteMitTest < Test::Unit::TestCase
  def setup
    @gateway = MitGateway.new(fixtures(:mit))

    @amount = 1115
    @amount_fail = 11165

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '5555555555555557',
      verification_value: '261',
      month: '09',
      year: '2025',
      first_name: 'Pedro',
      last_name: 'Flores Valdes'
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '318',
      month: '09',
      year: '2025',
      first_name: 'Pedro',
      last_name: 'Flores Valdes'
    )

    @credit_card_3ds = ActiveMerchant::Billing::CreditCard.new(
      number: '5555555555555557',
      verification_value: '261',
      month: '09',
      year: '2025',
      first_name: 'Pedro',
      last_name: 'Flores Valdes'
    )

    @declined_card_3ds = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '318',
      month: '09',
      year: '2025',
      first_name: 'Pedro',
      last_name: 'Flores Valdes'
    )

    @options_success = {
      order_id: '721',
      transaction_id: '721', # unique id for every transaction, needs to be generated for every test
      billing_address: address,
      description: 'Store Purchase'
    }

    @options = {
      order_id: '721',
      transaction_id: '721', # unique id for every transaction, needs to be generated for every test
      billing_address: address,
      description: 'Store Purchase',
      api_key: fixtures(:mit)[:apikey]
    }

    @three_ds_options = @options.merge({
      execute_threed: true,
      redirect_type: 1,
      billing_address1: '456 My Street',
      billing_city: 'City',
      billing_state: 'State',
      billing_zip: '55800',
      billing_country: 'MX',
      billing_phone_number: '+15675657821',
      redirect_url: 'www.example.com',
      callback_url: 'www.example.com'
    })
  end

  def test_successful_purchase_with_3ds1
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options_success[:order_id] = 'TID|' + time
    response = @gateway.purchase(@amount, @credit_card, @options_success.merge(@three_ds_options))
    assert_success response
    assert_equal 'approved', response.message
    assert response.params['url'].present?
  end

  def test_successful_purchase
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options_success[:order_id] = 'TID|' + time
    response = @gateway.purchase(@amount, @credit_card, @options_success)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount_fail, @declined_card, @options)
    assert_failure response
    assert_not_equal 'approved', response.message
  end

  def test_successful_authorize_and_capture
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options_success[:order_id] = 'TID|' + time
    auth = @gateway.authorize(@amount, @credit_card, @options_success)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options_success)
    assert_success capture
    assert_equal 'approved', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount_fail, @declined_card, @options)
    assert_failure response
    assert_not_equal 'approved', response.message
  end

  def test_failed_capture
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options[:order_id] = 'TID|' + time
    response = @gateway.capture(@amount_fail, 'requiredauth', @options)
    assert_failure response
    assert_not_equal 'approved', response.message
  end

  def test_successful_refund
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options_success[:order_id] = 'TID|' + time
    purchase = @gateway.purchase(@amount, @credit_card, @options_success)
    assert_success purchase

    # authorization is required
    assert refund = @gateway.refund(@amount, purchase.authorization, @options_success)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_failed_refund
    # ###############################################################
    # create unique id based on timestamp for testing purposes
    # Each order / transaction passed to the gateway must be unique
    time = Time.now.to_i.to_s
    @options[:order_id] = 'TID|' + time
    response = @gateway.refund(@amount, 'invalidauth', @options)
    assert_failure response
    assert_not_equal 'approved', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options_success)
    end

    clean_transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value, clean_transcript)
    assert_scrubbed(@gateway.options[:api_key], clean_transcript)
    assert_scrubbed(@gateway.options[:key_session], clean_transcript)
  end
end
