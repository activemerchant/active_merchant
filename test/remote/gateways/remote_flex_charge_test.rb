require 'timecop'
require 'test_helper'

class RemoteFlexChargeTest < Test::Unit::TestCase
  def setup
    @gateway = FlexChargeGateway.new(fixtures(:flex_charge))

    @amount = 100
    @credit_card_cit = credit_card('4111111111111111', verification_value: '123')
    @credit_card_mit = credit_card('4000002760003184')
    @declined_card = credit_card('4000300011112220')

    @options = {
      is_mit: true,
      is_recurring: false,
      mit_expiry_date_utc: (Time.now + 1.day).getutc.iso8601,
      description: 'MyShoesStore',
      is_declined: true,
      order_id: SecureRandom.uuid,
      idempotency_key: SecureRandom.uuid,
      card_not_present: true,
      email: 'test@gmail.com',
      response_code: '100',
      response_code_source: 'nmi',
      avs_result_code: '200',
      cvv_result_code: '111',
      cavv_result_code: '111',
      timezone_utc_offset: '-5',
      billing_address: address.merge(name: 'Cure Tester')
    }

    @cit_options = @options.merge({
      is_mit: false,
      phone: '+99.2001a/+99.2001b'
    })

    @mit_recurring_options = @options.merge({
      is_recurring: true,
      subscription_id: SecureRandom.uuid,
      subscription_interval: 'monthly'
    })

    @tokenize_cit_options = @cit_options.merge(tokenize: true)

    @tokenize_mit_options = @options.merge(tokenize: true)
  end

  def test_successful_cit_challenge_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success response
    assert_equal 'CHALLENGE', response.message
  end

  def test_successful_tokenize_cit_challenge_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, @tokenize_cit_options)
    assert_success response
    assert_kind_of MultiResponse, response
    assert_equal 'CHALLENGE', response.message
  end

  def test_successful_mit_submitted_purchase
    response = @gateway.purchase(@amount, @credit_card_mit, @tokenize_mit_options)
    assert_success response
    assert_kind_of MultiResponse, response
    assert_equal 'SUBMITTED', response.message
  end

  def test_successful_tokenize_mit_submitted_purchase
    response = @gateway.purchase(@amount, @credit_card_mit, @tokenize_mit_options)
    assert_success response
    assert_equal 'SUBMITTED', response.message
  end

  def test_successful_mit_recurring_submitted_purchase
    response = @gateway.purchase(@amount, @credit_card_mit, @mit_recurring_options)
    assert_success response
    assert_equal 'SUBMITTED', response.message
  end

  def test_successful_purchase_with_an_existing_access_token
    assert_nil @gateway.options[:access_token]
    purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success purchase

    access_token = @gateway.options[:access_token]

    second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success second_purchase

    assert_equal @gateway.options[:access_token], access_token
  end

  def test_successful_purchase_with_an_initial_invalid_access_token
    initial_access_token = 'SOMECREDENTIAL'
    gateway = FlexChargeGateway.new(fixtures(:flex_charge).merge(access_token: initial_access_token))
    assert_equal gateway.options[:access_token], initial_access_token
    purchase = gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success purchase

    new_access_token = gateway.options[:access_token]

    assert_not_equal initial_access_token, new_access_token
  end

  def test_successful_purchase_with_an_initial_expired_access_token
    purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success purchase

    initial_access_token = @gateway.options[:access_token]
    initial_expires = @gateway.options[:expires]

    Timecop.freeze(DateTime.now + 10.minutes) do
      second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
      assert_success second_purchase

      new_access_token = @gateway.options[:access_token]
      new_expires = @gateway.options[:expires]

      assert_not_equal initial_access_token, new_access_token
      assert_not_equal initial_expires, new_expires
    end
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, { billing_address: address })
    assert_failure response
    assert_equal nil, response.error_code
    assert_match(/TraceId/, response.message)
  end

  def test_failed_cit_declined_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options.except(:phone))
    assert_failure response
    assert_equal 'DECLINED', response.error_code
  end

  # def test_successful_authorize_and_capture
  #   @cit_options[:billing_address][:phone] = '+18001234433'
  #   auth = @gateway.authorize(@amount, @credit_card_mit, @cit_options)
  #   assert_success auth
  #   binding.pry

  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', capture.message
  # end

  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @credit_card_cit, @cit_options)
  #   assert_failure response
  #   assert_equal 'DECLINED', response.message
  # end

  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card_cit, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount - 1, auth.authorization)
  #   assert_success capture
  # end

  # def test_failed_capture
  #   response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  # end

  # def test_successful_refund
  #   purchase = @gateway.purchase(@amount, @credit_card_cit, @options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount, purchase.authorization)
  #   assert_success refund
  #   assert_equal 'REPLACE WITH SUCCESSFUL REFUND MESSAGE', refund.message
  # end

  # def test_partial_refund
  #   purchase = @gateway.purchase(@amount, @credit_card_cit, @options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount - 1, purchase.authorization)
  #   assert_success refund
  # end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Not Found', response.message
    assert_equal nil, response.error_code
  end

  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @credit_card_cit, @options)
  #   assert_success auth

  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  #   assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  # end

  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  # end

  # def test_successful_verify
  #   response = @gateway.verify(@credit_card_cit, @options)
  #   assert_success response
  #   assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  # end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end

  def test_invalid_login
    gateway = FlexChargeGateway.new(
      app_key: 'SOMECREDENTIAL',
      app_secret: 'SOMECREDENTIAL',
      site_id: 'SOMECREDENTIAL',
      mid: 'SOMECREDENTIAL'
    )

    assert response = gateway.purchase(@amount, @credit_card_cit, @options)
    assert_failure response
    assert_match(/400/, response.message)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card_cit.number, transcript)
    assert_scrubbed(@credit_card_cit.verification_value, transcript)
    assert_scrubbed(@gateway.options[:access_token], transcript)
    assert_scrubbed(@gateway.options[:app_key], transcript)
    assert_scrubbed(@gateway.options[:app_secret], transcript)
    assert_scrubbed(@gateway.options[:site_id], transcript)
    assert_scrubbed(@gateway.options[:mid], transcript)
    assert_scrubbed(@gateway.options[:tokenization_key], transcript)
  end
end
