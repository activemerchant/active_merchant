require 'test_helper'
require 'timecop'

class RemoteNuveiTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiGateway.new(fixtures(:nuvei))

    @amount = 100
    @credit_card = credit_card('4761344136141390', verification_value: '999', first_name: 'Cure', last_name: 'Tester')
    @declined_card = credit_card('4000128449498204')
    @challenge_credit_card = credit_card('2221008123677736', first_name: 'CL-BRW2', last_name: '')
    @three_ds_amount = 151 # for challenge = 151, for frictionless >= 150
    @frictionless_credit_card = credit_card('4000020951595032', first_name: 'FL-BRW1', last_name: '')

    @options = {
      email: 'test@gmail.com',
      billing_address: address.merge(name: 'Cure Tester'),
      ip_address: '127.0.0.1'
    }

    @post = {
      merchantId: 'test_merchant_id',
      merchantSiteId: 'test_merchant_site_id',
      clientRequestId: 'test_client_request_id',
      amount: 'test_amount',
      currency: 'test_currency',
      timeStamp: 'test_time_stamp'
    }

    @three_ds_options = {
      execute_threed: true,
      redirect_url: 'http://www.example.com/redirect',
      callback_url: 'http://www.example.com/callback',
      three_ds_2: {
        browser_info:  {
          width: 390,
          height: 400,
          depth: 24,
          timezone: 300,
          user_agent: 'Spreedly Agent',
          java: false,
          javascript: true,
          language: 'en-US',
          browser_size: '05',
          accept_header: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
      }
    }
  end

  def test_calculate_checksum
    expected_checksum = Digest::SHA256.hexdigest("test_merchant_idtest_merchant_site_idtest_client_request_idtest_amounttest_currencytest_time_stamp#{@gateway.options[:secret_key]}")
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :purchase)
  end

  def test_calculate_checksum_authenticate
    expected_checksum = Digest::SHA256.hexdigest("test_merchant_idtest_merchant_site_idtest_client_request_idtest_time_stamp#{@gateway.options[:secret_key]}")
    @post.delete(:amount)
    @post.delete(:currency)
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :authenticate)
  end

  def test_calculate_checksum_capture
    expected_checksum = Digest::SHA256.hexdigest("test_merchant_idtest_merchant_site_idtest_client_request_idtest_client_idtest_amounttest_currencytest_transaction_idtest_time_stamp#{@gateway.options[:secret_key]}")
    @post[:clientUniqueId] = 'test_client_id'
    @post[:relatedTransactionId] = 'test_transaction_id'
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :capture)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end

    @gateway.scrub(transcript)
  end

  def test_successful_session_token_generation
    response = @gateway.send(:fetch_session_token, @options)
    assert_success response
    assert_not_nil response.params[:sessionToken]
  end

  def test_failed_session_token_generation
    @gateway.options[:merchant_site_id] = 123
    response = @gateway.send(:fetch_session_token, {})
    assert_failure response
    assert_match 'ERROR', response.params['status']
    assert_match 'Invalid merchant site id', response.params['reason']
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.params['transactionStatus']
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    capture_response = @gateway.capture(@amount, response.authorization)

    assert_success capture_response
    assert_match 'SUCCESS', capture_response.params['status']
    assert_match 'APPROVED', capture_response.message
  end

  def test_successful_zero_auth
    response = @gateway.authorize(0, @credit_card, @options)
    assert_success response

    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_successful_purchase_with_3ds_frictionless
    response = @gateway.purchase(@three_ds_amount, @frictionless_credit_card, @options.merge(@three_ds_options))
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end

  def test_successful_purchase_with_3ds_challenge
    response = @gateway.purchase(@three_ds_amount, @challenge_credit_card, @options.merge(@three_ds_options))
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'SUCCESS', response.params['status']
    assert_match 'REDIRECT', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.params['transactionStatus']
  end

  def test_failed_purchase_with_invalid_cvv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'ERROR', response.params['transactionStatus']
    assert_match 'Invalid CVV2', response.message
  end

  def test_failed_capture_invalid_transaction_id
    response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_match 'ERROR', response.params['status']
    assert_match 'Invalid relatedTransactionId', response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void_response = @gateway.void(response.authorization)
    assert_success void_response
    assert_match 'SUCCESS', void_response.params['status']
    assert_match 'APPROVED', void_response.message
  end

  def test_failed_void_invalid_transaction_id
    response = @gateway.void('123')
    assert_failure response
    assert_match 'ERROR', response.params['status']
    assert_match 'Invalid relatedTransactionId', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
    assert_match 'SUCCESS', refund_response.params['status']
    assert_match 'APPROVED', refund_response.message
  end

  def test_successful_general_credit
    credit_response = @gateway.credit(@amount, @credit_card, @options.merge!(user_token_id: '123'))
    assert_success credit_response
    assert_match 'SUCCESS', credit_response.params['status']
    assert_match 'APPROVED', credit_response.message
  end

  def test_failed_general_credit
    credit_response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure credit_response
    assert_match 'ERROR', credit_response.params['status']
    assert_match 'Invalid user token', credit_response.message
  end

  def test_successful_store
    response = @gateway.store(@amount, @credit_card, @options.merge(savePM: true))
    assert_success response
    assert_match 'SUCCESS', response.params['status']
    assert_match 'APPROVED', response.message
  end
end
