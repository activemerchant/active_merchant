require 'test_helper'

class MonerisUsRemoteTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = MonerisUsGateway.new(fixtures(:moneris_us))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @check = check({
      routing_number: '011000015',
      account_number: '1234455',
      number: 123
    })
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'Registered', response.message
    assert response.authorization
  end

  def test_failed_echeck_purchase
    response = @gateway.purchase(105, check(routing_number: 5), @options)
    assert_failure response
    assert response.test?
    assert_equal 'Unspecified error', response.message
  end

  def test_successful_authorization
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization
  end

  def test_failed_verify
    response = @gateway.verify(credit_card(nil), @options)
    assert_failure response
    assert_match %r{Invalid pan parameter}, response.message
  end

  def test_failed_authorization
    response = @gateway.authorize(105, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorization_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end

  def test_successful_authorization_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    # Moneris cannot void a preauthorization
    # You must capture the auth transaction with an amount of $0.00
    void = @gateway.capture(0, response.authorization)
    assert_success void
  end

  def test_successful_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_failed_purchase_and_void
    purchase = @gateway.purchase(101, @credit_card, @options)
    assert_failure purchase

    void = @gateway.void(purchase.authorization)
    assert_failure void
  end

  def test_successful_purchase_and_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_purchase_from_error
    assert response = @gateway.purchase(150, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Successfully registered cc details', response.message
    assert response.params['data_key'].present?
    @data_key = response.params['data_key']
  end

  def test_successful_echeck_store
    assert response = @gateway.store(@check)
    assert_success response
    assert_equal 'Successfully registered ach details', response.message
    assert response.params['data_key'].present?
    @data_key_echeck = response.params['data_key']
  end

  def test_successful_unstore
    test_successful_store
    assert response = @gateway.unstore(@data_key)
    assert_success response
    assert_equal 'Successfully deleted cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_successful_echeck_unstore
    test_successful_echeck_store
    assert response = @gateway.unstore(@data_key_echeck)
    assert_success response
    assert_equal 'Successfully deleted ach details', response.message
    assert response.params['data_key'].present?
  end

  def test_update
    test_successful_store
    assert response = @gateway.update(@data_key, @credit_card)
    assert_success response
    assert_equal 'Successfully updated cc details', response.message
    assert response.params['data_key'].present?
  end

  def test_echeck_update
    test_successful_echeck_store
    assert response = @gateway.update(@data_key_echeck, @check)
    assert_success response
    assert_equal 'Successfully updated ach details', response.message
    assert response.params['data_key'].present?
  end

  def test_successful_purchase_with_vault
    test_successful_store
    assert response = @gateway.purchase(@amount, @data_key, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_authorization_with_vault
    test_successful_store
    assert response = @gateway.authorize(@amount, @data_key, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_failed_authorization_with_vault
    test_successful_store
    response = @gateway.authorize(105, @data_key, @options)
    assert_failure response
  end

  def test_cvv_match_when_not_enabled
    assert response = @gateway.purchase(1039, @credit_card, @options)
    assert_success response
    assert_equal({'code' => nil, 'message' => nil}, response.cvv_result)
  end

  def test_cvv_no_match_when_not_enabled
    assert response = @gateway.purchase(1053, @credit_card, @options)
    assert_success response
    assert_equal({'code' => nil, 'message' => nil}, response.cvv_result)
  end

  def test_cvv_match_when_enabled
    gateway = MonerisGateway.new(fixtures(:moneris).merge(cvv_enabled: true))
    assert response = gateway.purchase(1039, @credit_card, @options)
    assert_success response
    assert_equal({'code' => 'M', 'message' => 'CVV matches'}, response.cvv_result)
  end

  def test_cvv_no_match_when_enabled
    gateway = MonerisGateway.new(fixtures(:moneris).merge(cvv_enabled: true))
    assert response = gateway.purchase(1053, @credit_card, @options)
    assert_success response
    assert_equal({'code' => 'N', 'message' => 'CVV does not match'}, response.cvv_result)
  end

  def test_avs_result_valid_when_enabled
    gateway = MonerisGateway.new(fixtures(:moneris).merge(avs_enabled: true))

    assert response = gateway.purchase(1010, @credit_card, @options)
    assert_success response
    assert_equal(response.avs_result, {
      'code' => 'A',
      'message' => 'Street address matches, but postal code does not match.',
      'street_match' => 'Y',
      'postal_match' => 'N'
    })
  end

  def test_avs_result_nil_when_address_absent
    gateway = MonerisGateway.new(fixtures(:moneris).merge(avs_enabled: true))

    assert response = gateway.purchase(1010, @credit_card, @options.tap { |x| x.delete(:billing_address) })
    assert_success response
    assert_equal(response.avs_result, {
      'code' => nil,
      'message' => nil,
      'street_match' => nil,
      'postal_match' => nil
    })
  end

  def test_avs_result_nil_when_efraud_disabled
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal(response.avs_result, {
      'code' => nil,
      'message' => nil,
      'street_match' => nil,
      'postal_match' => nil
    })
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
