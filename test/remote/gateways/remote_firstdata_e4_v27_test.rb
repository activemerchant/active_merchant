require 'test_helper'

class RemoteFirstdataE4V27Test < Test::Unit::TestCase
  def setup
    @gateway = FirstdataE4V27Gateway.new(fixtures(:firstdata_e4_v27))
    @credit_card = credit_card
    @credit_card_master = credit_card('5500000000000004', :brand => 'master')
    @bad_credit_card = credit_card('4111111111111113')
    @credit_card_with_track_data = credit_card_with_track_data('4003000123456781')
    @amount = 100
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @options_with_authentication_data = @options.merge({
      eci: '5',
      cavv: 'TESTCAVV',
      xid: 'TESTXID'
    })
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_network_tokenization
    @credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: nil
    )
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Normal - Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_track_data
    assert response = @gateway.purchase(@amount, @credit_card_with_track_data, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_level_3
    level_3_xml = <<-LEVEL3
        <LineItem>
          <LineItemTotal>107.20</LineItemTotal>
          <Quantity>3</Quantity>
          <Description>The Description</Description>
          <UnitCost>2.33</UnitCost>
        </LineItem>
    LEVEL3

    response = @gateway.purchase(500, @credit_card, @options.merge(level_3: level_3_xml))
    assert_success response
    assert_equal 'Transaction Normal - Approved', response.message
  end

  def test_successful_purchase_with_tax_fields
    response = @gateway.purchase(500, @credit_card, @options.merge(tax1_amount: 50, tax1_number: 'A458'))
    assert_success response
    assert_equal '50.0', response.params['tax1_amount']
    assert_equal '', response.params['tax1_number'], 'E4 blanks this out in the response'
  end

  def test_successful_purchase_with_customer_ref
    response = @gateway.purchase(500, @credit_card, @options.merge(customer: '267'))
    assert_success response
    assert_equal '267', response.params['customer_ref']
  end

  def test_successful_purchase_with_card_authentication
    assert response = @gateway.purchase(@amount, @credit_card, @options_with_authentication_data)
    assert_equal response.params['cavv'], @options_with_authentication_data[:cavv]
    assert_equal response.params['ecommerce_flag'], @options_with_authentication_data[:eci]
    assert_equal response.params['xid'], @options_with_authentication_data[:xid]
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_initial
    stored_credential = {
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'customer'
      }
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
    assert_equal '1', response.params['stored_credentials_indicator']
    assert_equal 'U', response.params['stored_credentials_schedule']
    assert_not_nil response.params['stored_credentials_transaction_id']
  end

  def test_successful_purchase_with_stored_credentials_initial_master
    stored_credential = {
      stored_credential: {
        initial_transaction: true,
        reason_type: 'unscheduled',
        initiator: 'customer'
      }
    }
    assert response = @gateway.purchase(@amount, @credit_card_master, @options.merge(stored_credential))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
    assert_equal 'S', response.params['stored_credentials_indicator']
    assert_equal 'U', response.params['stored_credentials_schedule']
    assert_not_nil response.params['stored_credentials_transaction_id']
  end

  def test_successful_purchase_with_stored_credentials_subsequent_recurring
    stored_credential = {
      stored_credential: {
        initial_transaction: false,
        reason_type: 'recurring',
        initiator: 'merchant'
      }
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
    assert_equal 'S', response.params['stored_credentials_indicator']
    assert_equal 'S', response.params['stored_credentials_schedule']
    assert_not_nil response.params['stored_credentials_transaction_id']
  end

  def test_unsuccessful_purchase
    # ask for error 13 response (Amount Error) via dollar amount 5,000 + error
    @amount = 501300
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_failure response
  end

  def test_bad_creditcard_number
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_match(/Invalid Credit Card/, response.message)
    assert_failure response
    assert_equal response.error_code, 'invalid_number'
  end

  def test_trans_error
    # ask for error 42 (unable to send trans) as the cents bit...
    @amount = 500042
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Unable to Send Transaction/, response.message) # 42 is 'unable to send trans'
    assert_failure response
    assert_equal response.error_code, 'processing_error'
  end

  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(29234, @credit_card, @options)
    assert_success purchase

    assert purchase.authorization
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_purchase_and_void_with_even_dollar_amount
    assert purchase = @gateway.purchase(5000, @credit_card, @options)
    assert_success purchase

    assert purchase.authorization
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'ET838747474;frob')
    assert_failure response
    assert_match(/Invalid Authorization Number/i, response.message)
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'Transaction Normal - Approved', response.message
    assert_equal '0.0', response.params['dollar_amount']
    assert_equal '05', response.params['transaction_type']
  end

  def test_failed_verify
    assert response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{Invalid Credit Card Number}, response.message
    assert_equal response.error_code, 'invalid_number'
  end

  def test_invalid_login
    gateway = FirstdataE4V27Gateway.new(:login    => 'NotARealUser',
                                        :password => 'NotARealPassword',
                                        :key_id   => 'NotARealKey',
                                        :hmac_key => 'NotARealHMAC')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{Unauthorized Request}, response.message
    assert_failure response
  end

  def test_response_contains_cvv_and_avs_results
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result['code']
    assert_equal '4', response.avs_result['code']
  end

  def test_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_refund_with_track_data
    assert purchase = @gateway.purchase(@amount, @credit_card_with_track_data, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = FirstdataE4V27Gateway.new(login: 'unknown', password: 'unknown', key_id: 'unknown', hmac_key: 'unknown')
    assert !gateway.verify_credentials
    gateway = FirstdataE4V27Gateway.new(login: fixtures(:firstdata_e4)[:login], password: 'unknown', key_id: 'unknown', hmac_key: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_transcript_scrubbing
    cc_with_different_cvc = credit_card(verification_value: '999')
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, cc_with_different_cvc, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(cc_with_different_cvc.number, transcript)
    assert_scrubbed(cc_with_different_cvc.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:hmac_key], transcript)
  end

end
