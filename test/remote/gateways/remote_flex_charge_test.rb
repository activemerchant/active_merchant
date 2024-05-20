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

  def test_successful_purchase_with_three_ds_global
    @options[:three_d_secure] = {
      version: '2.1.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
      xid: 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      cavv_algorithm: 'AAABCSIIAAAAAAACcwgAEMCoNh=',
      enrolled: 'Y',
      authentication_response_status: 'Y'
    }

    response = @gateway.purchase(@amount, @credit_card_cit, @options)
    assert_success response
    assert_match 'SUBMITTED', response.message
  end

  def test_setting_access_token_when_no_present
    assert_nil @gateway.options[:access_token]

    @gateway.send(:fetch_access_token)

    assert_not_nil @gateway.options[:access_token]
    assert_not_nil @gateway.options[:token_expires]
  end

  def test_successful_access_token_generation_and_use
    @gateway.send(:fetch_access_token)

    second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)

    assert_success second_purchase
    assert_kind_of MultiResponse, second_purchase
    assert_equal 1, second_purchase.responses.size
    assert_equal @gateway.options[:access_token], second_purchase.params[:access_token]
  end

  def test_successful_purchase_with_an_expired_access_token
    initial_access_token = @gateway.options[:access_token] = SecureRandom.alphanumeric(10)
    initial_expires = @gateway.options[:token_expires] = DateTime.now.strftime('%Q').to_i

    Timecop.freeze(DateTime.now + 10.minutes) do
      second_purchase = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
      assert_success second_purchase

      assert_equal 2, second_purchase.responses.size
      assert_not_equal initial_access_token, @gateway.options[:access_token]
      assert_not_equal initial_expires, @gateway.options[:token_expires]

      assert_not_nil second_purchase.params[:access_token]
      assert_not_nil second_purchase.params[:token_expires]

      assert_nil second_purchase.responses.first.params[:access_token]
    end
  end

  def test_should_reset_access_token_when_401_error
    @gateway.options[:access_token] = SecureRandom.alphanumeric(10)
    @gateway.options[:token_expires] = DateTime.now.strftime('%Q').to_i + 15000

    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options)

    assert_equal '', response.params['access_token']
  end

  def test_successful_purchase_cit_challenge_purchase
    set_credentials!
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options)
    assert_success response
    assert_equal 'CHALLENGE', response.message
  end

  def test_successful_purchase_mit
    set_credentials!
    response = @gateway.purchase(@amount, @credit_card_mit, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    set_credentials!
    response = @gateway.purchase(@amount, @credit_card_cit, billing_address: address)
    assert_failure response
    assert_equal nil, response.error_code
    assert_not_nil response.params['TraceId']
  end

  def test_failed_cit_declined_purchase
    set_credentials!
    response = @gateway.purchase(@amount, @credit_card_cit, @cit_options.except(:phone))
    assert_failure response
    assert_equal 'DECLINED', response.error_code
  end

  def test_successful_refund
    set_credentials!
    purchase = @gateway.purchase(@amount, @credit_card_mit, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'DECLINED', refund.message
  end

  def test_partial_refund
    omit('Partial refunds requires to raise some limits on merchant account')
    set_credentials!
    purchase = @gateway.purchase(100, @credit_card_cit, @options)
    assert_success purchase

    assert refund = @gateway.refund(90, purchase.authorization)
    assert_success refund
    assert_equal 'DECLINED', refund.message
  end

  def test_failed_fetch_access_token
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = FlexChargeGateway.new(
        app_key: 'SOMECREDENTIAL',
        app_secret: 'SOMECREDENTIAL',
        site_id: 'SOMECREDENTIAL',
        mid: 'SOMECREDENTIAL'
      )
      gateway.send :fetch_access_token
    end

    assert_match(/400/, error.message)
  end

  def test_successful_purchase_with_token
    store = @gateway.store(@credit_card_cit, {})
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
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

  private

  def set_credentials!
    if FlexChargeCredentials.instance.access_token.nil?
      @gateway.send :fetch_access_token
      FlexChargeCredentials.instance.access_token = @gateway.options[:access_token]
      FlexChargeCredentials.instance.token_expires = @gateway.options[:token_expires]
    end

    @gateway.options[:access_token] = FlexChargeCredentials.instance.access_token
    @gateway.options[:token_expires] = FlexChargeCredentials.instance.token_expires
  end
end

# A simple singleton so access-token and expires can
# be shared among several tests
class FlexChargeCredentials
  include Singleton

  attr_accessor :access_token, :token_expires
end
