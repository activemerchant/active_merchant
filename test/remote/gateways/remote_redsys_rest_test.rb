require 'test_helper'

class RemoteRedsysRestTest < Test::Unit::TestCase
  def setup
    @gateway = RedsysRestGateway.new(fixtures(:redsys_rest))
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

  def test_purchase_with_invalid_order_id
    response = @gateway.purchase(@amount, @credit_card, order_id: "a%4#{generate_order_id}")
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
    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
  end

  def test_purchase_and_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    refund = @gateway.refund(@amount + 100, purchase.authorization, @options)
    assert_failure refund
    assert_equal 'SIS0057 ERROR', refund.message
  end

  def test_failed_purchase_with_unsupported_currency
    response = @gateway.purchase(600, @credit_card, @options.merge(currency: 'PEN'))
    assert_failure response
    assert_equal 'SIS0027 ERROR', response.message
  end

  def test_successful_authorize_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Transaction Approved', authorize.message
    assert_not_nil authorize.authorization

    capture = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success capture
    assert_match(/Refund.*approved/, capture.message)
  end

  def test_successful_authorize_and_failed_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal 'Transaction Approved', authorize.message
    assert_not_nil authorize.authorization

    capture = @gateway.capture(2 * @amount, authorize.authorization, @options)
    assert_failure capture
    assert_match(/SIS0062 ERROR/, capture.message)
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refusal with no specific reason', response.message
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization, @options)
    assert_success void
    assert_equal '100', void.params['ds_amount']
    assert_equal 'Cancellation Accepted', void.message
  end

  def test_failed_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    authorization = "#{authorize.params[:ds_order]}|#{@amount}|203"
    void = @gateway.void(authorization, @options)
    assert_failure void
    assert_equal 'SIS0027 ERROR', void.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'Transaction Approved', response.message
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

  def test_encrypt_handles_url_safe_character_in_secret_key_without_error
    gateway = RedsysRestGateway.new({
      login: '091952713',
      secret_key: 'yG78qf-PkHyRzRiZGSTCJdO2TvjWgFa8'
    })
    response = gateway.purchase(@amount, @credit_card, @options)
    assert response
  end

  # Pending 3DS support
  # def test_successful_authorize_3ds_setup
  #   options = @options.merge(execute_threed: true, terminal: 12)
  #   response = @gateway.authorize(@amount, @credit_card, options)
  #   assert_success response
  #   assert response.params['ds_emv3ds']
  #   assert_equal '2.2.0', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
  #   assert_equal 'CardConfiguration', response.message
  #   assert response.authorization
  # end

  # Pending 3DS support
  # def test_successful_purchase_3ds
  #   options = @options.merge(execute_threed: true)
  #   response = @gateway.purchase(@amount, @threeds2_credit_card, options)
  #   assert_success response
  #   assert three_ds_data = JSON.parse(response.params['ds_emv3ds'])
  #   assert_equal '2.1.0', three_ds_data['protocolVersion']
  #   assert_equal 'https://sis-d.redsys.es/sis-simulador-web/threeDsMethod.jsp', three_ds_data['threeDSMethodURL']
  #   assert_equal 'CardConfiguration', response.message
  #   assert response.authorization
  # end

  # Pending 3DS support
  # Requires account configuration to allow setting moto flag
  # def test_purchase_with_moto_flag
  #   response = @gateway.purchase(@amount, @credit_card, @options.merge(moto: true, metadata: { manual_entry: true }))
  #   assert_equal 'SIS0488 ERROR', response.message
  # end

  # Pending 3DS support
  # def test_successful_3ds_authorize_with_exemption
  #   options = @options.merge(execute_threed: true, terminal: 12)
  #   response = @gateway.authorize(@amount, @credit_card, options.merge(sca_exemption: 'LWV'))
  #   assert_success response
  #   assert response.params['ds_emv3ds']
  #   assert_equal 'NO_3DS_v2', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
  #   assert_equal 'CardConfiguration', response.message
  # end

  # Pending 3DS support
  # def test_successful_3ds_purchase_with_exemption
  #   options = @options.merge(execute_threed: true, terminal: 12)
  #   response = @gateway.purchase(@amount, @credit_card, options.merge(sca_exemption: 'LWV'))
  #   assert_success response
  #   assert response.params['ds_emv3ds']
  #   assert_equal 'NO_3DS_v2', JSON.parse(response.params['ds_emv3ds'])['protocolVersion']
  #   assert_equal 'CardConfiguration', response.message
  # end

  private

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
