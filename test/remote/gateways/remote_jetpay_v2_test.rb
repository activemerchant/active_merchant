require 'test_helper'

class RemoteJetpayV2Test < Test::Unit::TestCase

  def setup
    @gateway = JetpayV2Gateway.new(fixtures(:jetpay_v2))

    @credit_card = credit_card('4000300020001000')

    @amount_approved = 9900
    @amount_declined = 5205

    @options = {
      :device => 'spreedly',
      :application => 'spreedly',
      :developer_id => 'GenkID',
      :billing_address => address(:city => 'Durham', :state => 'NC', :country => 'US', :zip => '27701'),
      :shipping_address => address(:city => 'Durham', :state => 'NC', :country => 'US', :zip => '27701'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount_approved, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount_declined, @credit_card, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
  end

  def test_successful_purchase_with_minimal_options
    assert response = @gateway.purchase(@amount_approved, @credit_card, {:device => 'spreedly', :application => 'spreedly'})
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end

  def test_successful_purchase_with_additional_options
    options = @options.merge(
      ud_field_1: "Value1",
      ud_field_2: "Value2",
      ud_field_3: "Value3"
      )
    assert response = @gateway.purchase(@amount_approved, @credit_card, options)
    assert_success response
  end

  def test_successful_authorize_and_capture
    assert auth = @gateway.authorize(@amount_approved, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(@amount_approved, auth.authorization, @options)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_tax
    assert auth = @gateway.authorize(@amount_approved, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(@amount_approved, auth.authorization, @options.merge(:tax_amount => '990', :purchase_order => 'ABC12345'))
    assert_success capture
  end

  def test_successful_partial_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(4400, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount_approved, '7605f7c5d6e8f74deb', @options)
    assert_failure response
    assert_equal 'Transaction Not Found.', response.message
  end

  def test_successful_void
    assert auth = @gateway.authorize(@amount_approved, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]


    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
  end

  def test_failed_void
    assert void = @gateway.void('bogus', @options)
    assert_failure void
  end

  def test_successful_purchase_refund
    assert response = @gateway.purchase(@amount_approved, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]

    assert refund = @gateway.refund(@amount_approved, response.authorization, @options)
    assert_success refund
    assert_not_nil(refund.authorization)
    assert_not_nil(response.params["approval"])
    assert_equal [response.params['transaction_id'], response.params["approval"], @amount_approved, response.params["token"]].join(";"), response.authorization
  end

  def test_successful_capture_refund
    assert auth = @gateway.authorize(@amount_approved, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]
    assert_equal [auth.params['transaction_id'], auth.params["approval"], @amount_approved, auth.params["token"]].join(";"), auth.authorization

    assert capture = @gateway.capture(@amount_approved, auth.authorization, @options)
    assert_success capture
    assert_equal [capture.params['transaction_id'], capture.params["approval"], @amount_approved, auth.params["token"]].join(";"), capture.authorization

    assert refund = @gateway.refund(@amount_approved, capture.authorization, @options)
    assert_success refund
    assert_not_nil(refund.authorization)
    assert_not_nil(refund.params["approval"])
  end

  def test_failed_refund
    assert refund = @gateway.refund(@amount_approved, 'bogus', @options)
    assert_failure refund
  end

  def test_successful_credit
    card = credit_card('4242424242424242', :verification_value => nil)

    assert credit = @gateway.credit(@amount_approved, card, @options)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(credit.params["approval"])
  end

  def test_failed_credit
    card = credit_card('2424242424242424', :verification_value => nil)

    assert credit = @gateway.credit(@amount_approved, card, @options)
    assert_failure credit
    assert_match %r{Invalid card format}, credit.message
  end

  def test_successful_verify
    assert verify = @gateway.verify(@credit_card, @options)
    assert_success verify
  end

  def test_failed_verify
    card = credit_card('2424242424242424', :verification_value => nil)

    assert verify = @gateway.verify(card, @options)
    assert_failure verify
    assert_match %r{Invalid card format}, verify.message
  end

  def test_invalid_login
    gateway = JetpayV2Gateway.new(:login => 'bogus')
    assert response = gateway.purchase(@amount_approved, @credit_card, @options)
    assert_failure response

    assert_equal 'Bad Terminal ID.', response.message
  end

  def test_missing_login
    gateway = JetpayV2Gateway.new(:login => '')
    assert response = gateway.purchase(@amount_approved, @credit_card, @options)
    assert_failure response

    assert_equal 'No response returned (missing credentials?).', response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = "421"
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount_approved, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
