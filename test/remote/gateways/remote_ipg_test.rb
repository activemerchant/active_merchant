require 'test_helper'

class RemoteIpgTest < Test::Unit::TestCase
  def setup
    @gateway = IpgGateway.new(fixtures(:ipg))
    @gateway_ma = IpgGateway.new(fixtures(:ipg_ma).merge({ store_id: nil }))
    @amount = 100
    @credit_card = credit_card('5165850000000008', brand: 'mastercard', month: '12', year: '2029')
    @declined_card = credit_card('4000300011112220', brand: 'mastercard', verification_value: '652', month: '12', year: '2022')
    @visa_card = credit_card('4704550000000005', brand: 'visa', verification_value: '123', month: '12', year: '2029')
    @options = {
      currency: 'ARS'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_purchase_with_store
    payment_token = generate_unique_id
    response = @gateway.store(@credit_card, @options.merge({ hosted_data_id: payment_token }))
    assert_success response
    assert_equal 'true', response.params['successfully']

    response = @gateway.purchase(@amount, payment_token, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_purchase_with_store_without_passing_hosted
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'true', response.params['successfully']
    payment_token = response.authorization
    assert payment_token

    response = @gateway.purchase(@amount, payment_token, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_unstore
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'true', response.params['successfully']
    payment_token = response.authorization
    assert payment_token

    response = @gateway.unstore(payment_token)
    assert_success response
    assert_equal 'true', response.params['successfully']
  end

  def test_successful_purchase_with_stored_credential
    @options[:stored_credential] = {
      initial_transaction: true,
      reason_type: '',
      initiator: 'merchant',
      network_transaction_id: nil
    }
    order_id = generate_unique_id
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge({ order_id: }))
    assert_success response

    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: '',
      initiator: 'merchant',
      network_transaction_id: response.params['IpgTransactionId']
    }

    assert recurring_purchase = @gateway.purchase(@amount, @credit_card, @options.merge({ order_id: }))
    assert_success recurring_purchase
    assert_equal 'APPROVED', recurring_purchase.message
  end

  def test_successful_purchase_with_3ds2_options
    options = @options.merge(
      three_d_secure: {
        version: '2.1.0',
        cavv: 'jEET5Odser3oCRAyNTY5BVgAAAA=',
        xid: 'jHDMyjJJF9bLBCFT/YUbqMhoQ0s=',
        directory_response_status: 'Y',
        authentication_response_status: 'Y',
        ds_transaction_id: '925a0317-9143-5130-8000-0000000f8742'
      }
    )
    response = @gateway.purchase(@amount, @visa_card, options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.message
    assert_equal 'SGS-050005', response.error_code
  end

  def test_failed_purchase_with_passed_in_store_id
    response = @gateway.purchase(@amount, @visa_card, @options.merge({ store_id: '1234' }))

    assert_failure response
    assert 'MerchantException', response.params['faultstring']
  end

  def test_successful_authorize_and_capture
    order_id = generate_unique_id
    response = @gateway.authorize(@amount, @credit_card, @options.merge!({ order_id: }))
    assert_success response
    assert_equal 'APPROVED', response.message

    capture = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture
    assert_equal 'APPROVED', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINED, Do not honour', response.message
    assert_equal 'SGS-050005', response.error_code
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_match 'FAILED', response.message
    assert_equal 'SGS-005001', response.error_code
  end

  def test_successful_void
    order_id = generate_unique_id
    response = @gateway.authorize(@amount, @credit_card, @options.merge!({ order_id: }))
    assert_success response

    void = @gateway.void(response.authorization, @options)
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def test_failed_void
    response = @gateway.void('', @options)
    assert_failure response
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization, @options)
    assert_success refund
    assert_equal 'APPROVED', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_match 'FAILED', response.message
    assert_equal 'SGS-005001', response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'APPROVED', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'DECLINED', response.message
    assert_equal 'SGS-050005', response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  def test_successful_purchase_with_ma_credentials
    response = @gateway_ma.purchase(@amount, @credit_card, @options.merge({ store_id: fixtures(:ipg_ma)[:store_id] }))
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase_without_store_id
    assert_raises(ArgumentError) do
      @gateway_ma.purchase(@amount, @credit_card, @options)
    end
  end
end
