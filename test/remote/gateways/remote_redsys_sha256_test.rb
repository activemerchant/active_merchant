require 'test_helper'

class RemoteRedsysSHA256Test < Test::Unit::TestCase
  def setup
    @gateway = RedsysGateway.new(fixtures(:redsys_sha256))
    @amount = 100
    @credit_card = credit_card('4548812049400004')
    @declined_card = credit_card
    @threeds2_credit_card = credit_card('4918019199883839')

    @threeds2_credit_card_frictionless = credit_card('4548814479727229')
    @threeds2_credit_card_alt = credit_card('4548817212493017')
    @options = {
      order_id: generate_order_id
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_threeds1_as_mpi_has_no_effect
    # 1.0.2 is NOT supported by RedSys External MPI; thus, behaviour should be same as if not present.
    xid = '97267598-FAE6-48F2-8083-C23433990FBC'
    cavv = '123'
    eci = '01'
    version = '1.0.2'

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        three_d_secure: {
          version: version,
          xid: xid,
          cavv: cavv,
          eci: eci
        },
        description: 'description',
        store: 'store',
        sca_exemption: 'MOTO'
      )
    )

    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_succesful_purchase_threeds1_as_mpi
    xid = '97267598-FAE6-48F2-8083-C23433990FBC'
    cavv = '123'
    eci = '01'
    version = '0.0.0'

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        three_d_secure: {
          version: version,
          xid: xid,
          cavv: cavv,
          eci: eci
        },
        description: 'description',
        store: 'store',
        sca_exemption: 'MOTO'
      )
    )

    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_purchase_threeds2_as_mpi
    three_ds_server_trans_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    eci = '01'
    version = '2.1.0'

    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(
        three_d_secure: {
          version: version,
          ds_transaction_id: ds_transaction_id,
          three_ds_server_trans_id: three_ds_server_trans_id,
          eci: eci
        },
        description: 'description',
        store: 'store',
        sca_exemption: 'MOTO'
      )
    )

    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_authorize_3ds
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert response.params['ds_emv3ds']
    assert_equal 'NO_3DS_v2', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'CardConfiguration', response.message
    assert response.authorization
  end

  def test_successful_purchase_3ds
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.purchase(@amount, @threeds2_credit_card, options)
    assert_success response
    assert three_ds_data = JSON.parse(response.params['ds_emv3ds'])
    assert_equal '2.1.0', three_ds_data['protocolVersion']
    assert_equal 'https://sis-d.redsys.es/sis-simulador-web/threeDsMethod.jsp', three_ds_data['threeDSMethodURL']
    assert_equal 'CardConfiguration', response.message
    assert response.authorization
  end

  # Requires account configuration to allow setting moto flag
  def test_purchase_with_moto_flag
    response = @gateway.purchase(@amount, @credit_card, @options.merge(moto: true, metadata: { manual_entry: true }))
    assert_equal 'SIS0488 ERROR', response.message
  end

  def test_successful_3ds_authorize_with_exemption
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.authorize(@amount, @credit_card, options.merge(sca_exemption: 'LWV'))
    assert_success response
    assert response.params['ds_emv3ds']
    assert_equal 'NO_3DS_v2', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'CardConfiguration', response.message
  end

  def test_successful_3ds_purchase_with_exemption
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.purchase(@amount, @credit_card, options.merge(sca_exemption: 'LWV'))
    assert_success response
    assert response.params['ds_emv3ds']
    assert_equal 'NO_3DS_v2', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'CardConfiguration', response.message
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

  def test_successful_auth_purchase_with_stored_credentials
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_response = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success initial_response
    assert_equal 'Transaction Approved', initial_response.message
    assert_not_nil initial_response.params['ds_merchant_cof_txnid']
    network_transaction_id = initial_response.params['ds_merchant_cof_txnid']

    used_options = @options.merge(
      order_id: generate_order_id,
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        network_transaction_id: network_transaction_id
      }
    )
    response = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success response
    assert_equal 'Transaction Approved', response.message
  end

  def test_successful_3ds2_purchase_with_mit_exemption
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.purchase(@amount, @threeds2_credit_card, options.merge(sca_exemption: 'MIT', sca_exemption_direct_payment_enabled: true))
    assert_success response
    assert response.params['ds_emv3ds']
    assert response.params['ds_card_psd2']
    assert_equal '2.1.0', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'Y', response.params['ds_card_psd2']
    assert_equal 'CardConfiguration', response.message

    # ensure MIT exemption is recognized
    assert response.params['ds_excep_sca']
    assert_match 'MIT', response.params['ds_excep_sca']
  end

  def test_successful_ntid_generation_with_verify
    # This test validates a special use case for generating a network transaction id
    # for payment methods that previously relied on the 'magic' fifteen-nines value.
    # However, the transaction id will only be returned from a Redsys production
    # environment, so this test simply validates that the zero-value request succeeds.

    alternate_gateway = RedsysGateway.new(fixtures(:redsys_sha256_alternate))
    options = @options.merge(
      sca_exemption_behavior_override: 'endpoint_and_ntid',
      sca_exemption: 'MIT',
      terminal: 2,
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        network_transaction_id: '999999999999999'
      }
    )
    response = alternate_gateway.verify(@credit_card, options)
    assert_success response
  end

  def test_failed_3ds2_purchase_with_mit_exemption_but_missing_direct_payment_enabled
    options = @options.merge(execute_threed: true, terminal: 12)
    response = @gateway.purchase(@amount, @threeds2_credit_card, options.merge(sca_exemption: 'MIT'))
    assert_success response
    assert response.params['ds_emv3ds']
    assert response.params['ds_card_psd2']
    assert_equal '2.1.0', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
    assert_equal 'Y', response.params['ds_card_psd2']
    assert_equal 'CardConfiguration', response.message

    # ensure MIT exemption is recognized
    assert response.params['ds_excep_sca']
    assert_match 'MIT', response.params['ds_excep_sca']
  end

  def test_successful_purchase_with_mit_exemption
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_response = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success initial_response
    assert_equal 'Transaction Approved', initial_response.message
    assert_not_nil initial_response.params['ds_merchant_cof_txnid']
    network_transaction_id = initial_response.params['ds_merchant_cof_txnid']

    used_options = @options.merge(
      order_id: generate_order_id,
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        network_transaction_id: network_transaction_id
      },
      sca_exemption: 'MIT',
      sca_exemption_direct_payment_enabled: true
    )

    response = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success response
    assert_equal response.message, 'Transaction Approved'
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
    assert_equal 'Refusal with no specific reason', response.message
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
    assert_equal 'Refusal with no specific reason', response.message
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
    assert_equal 'Refusal with no specific reason', response.message
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

  private

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
