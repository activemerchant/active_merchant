require 'timecop'
require 'test_helper'

class RemoteFlexChargeTest < Test::Unit::TestCase
  def setup
    @gateway = FlexChargeGateway.new(fixtures(:flex_charge))

    @amount = 100
    @credit_card_cit = credit_card('4111111111111111', verification_value: '999', first_name: 'Cure', last_name: 'Tester')
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
      card_not_present: false,
      email: 'test@gmail.com',
      response_code: '100',
      response_code_source: 'nmi',
      avs_result_code: '200',
      cvv_result_code: '111',
      cavv_result_code: '111',
      timezone_utc_offset: '-5',
      billing_address: address.merge(name: 'Cure Tester')
    }

    @cit_options = @options.merge(
      is_mit: false,
      phone: '+99.2001a/+99.2001b'
    )
  end

  def test_setting_access_token_when_no_present
    assert_nil @gateway.options[:access_token]

    @gateway.send(:refresh_access_token)

    assert_not_nil @gateway.options[:access_token]
    assert_not_nil @gateway.options[:expires]
  end

  def test_successful_access_token_generation_and_use
    @gateway.send(:refresh_access_token)

    second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)

    assert_success second_purchase
    assert_kind_of MultiResponse, second_purchase
    assert_equal 1, second_purchase.responses.size
    assert_equal @gateway.options[:access_token], second_purchase.params[:access_token]
  end

  def test_successful_purchase_with_an_expired_access_token
    initial_access_token = @gateway.options[:access_token] = SecureRandom.alphanumeric(10)
    initial_expires = @gateway.options[:expires] = DateTime.now.strftime('%Q').to_i + 5000

    Timecop.freeze(DateTime.now + 10.minutes) do
      second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
      assert_success second_purchase

      assert_not_equal initial_access_token, @gateway.options[:access_token]
      assert_not_equal initial_expires, @gateway.options[:expires]
    end
  end

  def test_successful_purchase_cit_challenge_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success response
    assert_equal 'CHALLENGE', response.message
  end

  def test_successful_purchase_mit
    response = @gateway.purchase(@amount, @credit_card_mit, @options)
    assert_success response

    assert_kind_of MultiResponse, response
    assert_equal 2, response.responses.size
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, billing_address: address)
    assert_failure response
    assert_equal nil, response.error_code
    assert_not_nil response.params['TraceId']
  end

  def test_failed_cit_declined_purchase
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options.except(:phone))
    assert_failure response
    assert_equal 'DECLINED', response.error_code
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card_mit, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(100, @credit_card_cit, @options)
    assert_success purchase

    assert refund = @gateway.refund(90, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_failed_refresh_access_token
    gateway = FlexChargeGateway.new(
      app_key: 'SOMECREDENTIAL',
      app_secret: 'SOMECREDENTIAL',
      site_id: 'SOMECREDENTIAL',
      mid: 'SOMECREDENTIAL'
    )

    assert response = gateway.purchase(@amount, @credit_card_cit, @options)
    assert_failure response
    assert_match(/One or more validation errors occurred/, response.message)
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
  end
end
