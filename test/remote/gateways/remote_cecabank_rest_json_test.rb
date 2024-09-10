require 'test_helper'

class RemoteCecabankTest < Test::Unit::TestCase
  def setup
    @gateway = CecabankJsonGateway.new(fixtures(:cecabank))

    @amount = 100
    @credit_card = credit_card('4507670001000009', { month: 12, year: Time.now.year, verification_value: '989' })
    @declined_card = credit_card('5540500001000004', { month: 11, year: Time.now.year + 1, verification_value: '001' })

    @options = {
      order_id: generate_unique_id,
      three_d_secure: three_d_secure,
      exemption_type: 'transaction_risk_analysis_exemption'
    }

    @cit_options = @options.merge({
      recurring_end_date: "#{Time.now.year}1231",
      recurring_frequency: '1',
      stored_credential: {
        reason_type: 'unscheduled',
        initiator: 'cardholder'
      }
    })

    @apple_pay_network_token = network_tokenization_credit_card(
      '4507670001000009',
      eci: '05',
      payment_cryptogram: 'xgQAAAAAAAAAAAAAAAAAAAAAAAAA',
      month: '12',
      year: Time.now.year,
      source: :apple_pay,
      verification_value: '989'
    )

    @google_pay_network_token = network_tokenization_credit_card(
      '4507670001000009',
      eci: '05',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: nil
    )
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal %i[codAut numAut referencia], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match @gateway.options[:merchant_id], response.message
    assert_match '190', response.error_code
  end

  def test_successful_capture
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert response = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success response
    assert_equal %i[codAut numAut referencia], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, 'abc123', @options)
    assert_failure response
    assert_match @gateway.options[:merchant_id], response.message
    assert_match '807', response.error_code
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, order_id: generate_unique_id)
    assert_success response
    assert_equal %i[codAut numAut referencia], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_successful_purchase_with_apple_pay
    assert response = @gateway.purchase(@amount, @apple_pay_network_token, { order_id: generate_unique_id })
    assert_success response
    assert_equal %i[codAut numAut referencia], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_successful_purchase_with_google_pay
    assert response = @gateway.purchase(@amount, @apple_pay_network_token, { order_id: generate_unique_id })
    assert_success response
    assert_equal %i[codAut numAut referencia], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_failed_purchase_with_apple_pay_sending_three_ds_data
    assert response = @gateway.purchase(@amount, @apple_pay_network_token, @options)
    assert_failure response
    assert_equal response.error_code, '1061'
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match @gateway.options[:merchant_id], response.message
    assert_match '190', response.error_code
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert response = @gateway.refund(@amount, purchase.authorization, order_id: @options[:order_id])
    assert_success response
    assert_equal %i[acquirerBIN codAut importe merchantID numAut numOperacion pais referencia terminalID tipoOperacion], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, 'reference', @options)
    assert_failure response
    assert_match @gateway.options[:merchant_id], response.message
    assert_match '15', response.error_code
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    assert response = @gateway.void(authorize.authorization, order_id: @options[:order_id])
    assert_success response
    assert_equal %i[acquirerBIN codAut importe merchantID numAut numOperacion pais referencia terminalID tipoOperacion], JSON.parse(response.message).symbolize_keys.keys.sort
  end

  def test_unsuccessful_void
    assert response = @gateway.void('reference', { order_id: generate_unique_id })
    assert_failure response
    assert_match @gateway.options[:merchant_id], response.message
    assert_match '15', response.error_code
  end

  def test_invalid_login
    gateway = CecabankGateway.new(fixtures(:cecabank).merge(cypher_key: 'invalid'))

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'ERROR AL CALCULAR FIRMA', response.message
  end

  def test_purchase_using_stored_credential_cit
    assert purchase = @gateway.purchase(@amount, @credit_card, @cit_options)
    assert_success purchase
  end

  def test_purchase_stored_credential_with_network_transaction_id
    @cit_options.merge!({ network_transaction_id: '999999999999999' })
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
  end

  def test_purchase_using_auth_capture_and_stored_credential_cit
    assert authorize = @gateway.authorize(@amount, @credit_card, @cit_options)
    assert_success authorize
    assert_equal authorize.network_transaction_id, '999999999999999'

    assert capture = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success capture
  end

  def test_purchase_with_apple_pay_using_stored_credential_recurring_mit
    @cit_options[:stored_credential][:reason_type] = 'installment'
    assert purchase = @gateway.purchase(@amount, @apple_pay_network_token, @cit_options.except(:three_d_secure))
    assert_success purchase

    options = @cit_options.except(:three_d_secure, :extra_options_for_three_d_secure)
    options[:stored_credential][:reason_type] = 'recurring'
    options[:stored_credential][:initiator] = 'merchant'
    options[:stored_credential][:network_transaction_id] = purchase.network_transaction_id
    options[:order_id] = generate_unique_id

    assert purchase2 = @gateway.purchase(@amount, @apple_pay_network_token, options)
    assert_success purchase2
  end

  def test_purchase_using_stored_credential_recurring_mit
    @cit_options[:stored_credential][:reason_type] = 'installment'
    assert purchase = @gateway.purchase(@amount, @credit_card, @cit_options)
    assert_success purchase

    options = @cit_options.except(:three_d_secure, :extra_options_for_three_d_secure)
    options[:stored_credential][:reason_type] = 'recurring'
    options[:stored_credential][:initiator] = 'merchant'
    options[:stored_credential][:network_transaction_id] = purchase.network_transaction_id
    options[:order_id] = generate_unique_id

    assert purchase2 = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase2
  end

  def test_failure_stored_credential_invalid_cit_transaction_id
    options = @cit_options
    options[:stored_credential][:reason_type] = 'recurring'
    options[:stored_credential][:initiator] = 'merchant'
    options[:stored_credential][:network_transaction_id] = 'bad_reference'

    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_failure purchase
    assert_match @gateway.options[:merchant_id], purchase.message
    assert_match '810', purchase.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  private

  def get_response_params(transcript)
    response = JSON.parse(transcript.gsub(%r(\\\")i, "'").scan(/{[^>]*}/).first.gsub("'", '"'))
    JSON.parse(Base64.decode64(response['parametros']))
  end

  def three_d_secure
    {
      version: '2.2.0',
      eci: '07',
      ds_transaction_id: 'a2bf089f-cefc-4d2c-850f-9153827fe070',
      acs_transaction_id: '18c353b0-76e3-4a4c-8033-f14fe9ce39dc',
      authentication_response_status: 'I',
      three_ds_server_trans_id: '9bd9aa9c-3beb-4012-8e52-214cccb25ec5',
      enrolled: 'true',
      cavv: 'AJkCC1111111111122222222AAAA',
      xid: '22222'
    }
  end
end
