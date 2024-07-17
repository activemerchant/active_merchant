require 'test_helper'
require 'timecop'

class RemoteNuveiTest < Test::Unit::TestCase
  def setup
    @gateway = NuveiGateway.new(fixtures(:nuvei))

    @amount = 100
    @credit_card = credit_card('4761344136141390', verification_value: '999', first_name: 'Cure', last_name: 'Tester')
    @declined_card = credit_card('4000128449498204')

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
    assert_match 'ERROR', response.message
    assert_match 'Invalid merchant site id', response.params['reason']
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params[:transactionId]
    assert_match 'SUCCESS', response.message
    assert_match 'APPROVED', response.params['transactionStatus']
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
    assert_match 'SUCCESS', capture_response.message
    assert_match 'APPROVED', capture_response.params['transactionStatus']
  end

  def test_successful_zero_auth
    response = @gateway.authorize(0, @credit_card, @options)
    assert_success response
    assert_match 'SUCCESS', response.message
    assert_match 'APPROVED', response.params['transactionStatus']
  end
end
