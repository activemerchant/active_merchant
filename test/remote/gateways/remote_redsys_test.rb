require 'test_helper'

class RemoteRedsysTest < Test::Unit::TestCase
  def setup
    @gateway = RedsysGateway.new(fixtures(:redsys))
    @amount = 100
    @credit_card = credit_card('4548812049400004')
    @declined_card = credit_card
    @options = {
      order_id: generate_order_id,
      description: 'Test Description'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_threeds2
    three_ds_server_trans_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    version = '2.1.0'
    eci = '02'

    response = @gateway.purchase(
      100,
      @credit_card,
      @options.merge(
        three_d_secure: {
          version: version,
          ds_transaction_id: ds_transaction_id,
          three_ds_server_trans_id: three_ds_server_trans_id,
          eci: eci
        }
      )
    )

    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_threeds1
    xid = '97267598-FAE6-48F2-8083-C23433990FBC'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    eci = '02'

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        three_d_secure: {
          eci: eci,
          cavv: cavv,
          xid: xid
        }
      )
    )

    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_with_stored_credentials
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_response = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success initial_response
    assert_equal 'Transaction Approved', initial_response.message
    assert_not_nil initial_response.params['ds_merchant_cof_txnid']
    network_transaction_id = initial_response.params['ds_merchant_cof_txnid']

    used_options = @options.merge(
      order_id: generate_order_id,
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        network_transaction_id: network_transaction_id
      }
    )
    response = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_purchase_with_invalid_order_id
    response = @gateway.purchase(@amount, @credit_card, order_id: "a%4#{generate_order_id}")
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_using_vault_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(store: true))
    assert_success response
    assert_equal 'Transaction Approved', response.message

    credit_card_token = response.params['ds_merchant_identifier']
    assert_not_nil credit_card_token

    @options[:order_id] = generate_order_id
    response = @gateway.purchase(@amount, credit_card_token, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'SIS0093 ERROR', response.message
  end

  def test_purchase_and_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  # Multiple currencies are not supported in test, but should at least fail.
  def test_purchase_and_refund_with_currency
    response = @gateway.purchase(600, @credit_card, @options.merge(currency: 'PEN'))
    assert_failure response
    assert_equal 'SIS0027 ERROR', response.message
  end

  def test_successful_authorise_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Transaction Approved', authorize.message
    assert_not_nil authorize.authorization

    capture = @gateway.capture(@amount, authorize.authorization)
    assert_success capture
    assert_match(/Refund.*approved/, capture.message)
  end

  def test_successful_authorise_using_vault_id
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(store: true))
    assert_success authorize
    assert_equal 'Transaction Approved', authorize.message
    assert_not_nil authorize.authorization

    credit_card_token = authorize.params['ds_merchant_identifier']
    assert_not_nil credit_card_token

    @options[:order_id] = generate_order_id
    authorize = @gateway.authorize(@amount, credit_card_token, @options)
    assert_success authorize
    assert_equal 'Transaction Approved', authorize.message
    assert_not_nil authorize.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'SIS0093 ERROR', response.message
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
    assert_equal '100', void.params['ds_amount']
    assert_equal 'Cancellation Accepted', void.message
  end

  def test_failed_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void

    another_void = @gateway.void(authorize.authorization)
    assert_failure another_void
    assert_equal 'SIS0222 ERROR', another_void.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'Transaction Approved', response.message
    assert_success response.responses.last, 'The void should succeed'
    assert_equal 'Cancellation Accepted', response.responses.last.message
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'SIS0093 ERROR', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:secret_key], clean_transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_transcript_scrubbing_on_failed_transactions
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @declined_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:secret_key], clean_transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_nil_cvv_transcript_scrubbing
    @credit_card.verification_value = nil
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_equal clean_transcript.include?('[BLANK]'), true
  end

  def test_empty_string_cvv_transcript_scrubbing
    @credit_card.verification_value = ''
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_equal clean_transcript.include?('[BLANK]'), true
  end

  def test_whitespace_string_cvv_transcript_scrubbing
    @credit_card.verification_value = '   '
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_equal clean_transcript.include?('[BLANK]'), true
  end

  def test_encrypt_handles_url_safe_character_in_secret_key_without_error
    gateway = RedsysGateway.new({
      login: '091952713',
      secret_key: 'yG78qf-PkHyRzRiZGSTCJdO2TvjWgFa8',
      terminal: '1',
      signature_algorithm: 'sha256'
    })
    response = gateway.purchase(@amount, @credit_card, @options)
    assert response
  end

  private

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
