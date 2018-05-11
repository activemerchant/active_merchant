require 'test_helper'

class RemoteJetpayTest < Test::Unit::TestCase

  def setup
    @gateway = JetpayGateway.new(fixtures(:jetpay))

    @credit_card = credit_card('4000300020001000')
    @declined_card = credit_card('4000300020001000')

    @options = {
      :billing_address => address(:country => 'US', :zip => '75008'),
      :shipping_address => address(:country => 'US'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345',
      :tax => 7
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(9900, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(5205, @declined_card, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
  end

  def test_successful_purchase_with_origin
    assert response = @gateway.purchase(9900, @credit_card, {:origin => 'RECURRING'})
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(9900, auth.authorization)
    assert_success capture
  end

  def test_partial_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]

    assert capture = @gateway.capture(4400, auth.authorization)
    assert_success capture
  end

  def test_ud_fields_on_purchase
    assert response = @gateway.purchase(9900, @credit_card, @options.merge(ud_field_1: "Value1", ud_field_2: "Value2", ud_field3: "Value3"))
    assert_success response
  end

  def test_ud_fields_on_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(9900, auth.authorization, @options.merge(ud_field_1: "Value1", ud_field_2: "Value2", ud_field3: "Value3"))
    assert_success capture
  end


  def test_void
    # must void a valid auth
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]


    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_purchase_refund_with_token
    assert response = @gateway.purchase(9900, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]

    # linked to a specific transaction_id
    assert credit = @gateway.refund(9900, response.authorization)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(response.params["approval"])
    assert_equal [response.params['transaction_id'], response.params["approval"], 9900, response.params["token"]].join(";"), response.authorization
  end

  def test_capture_refund_with_token
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]
    assert_equal [auth.params['transaction_id'], auth.params["approval"], 9900, auth.params["token"]].join(";"), auth.authorization

    assert capture = @gateway.capture(9900, auth.authorization)
    assert_success capture
    assert_equal [capture.params['transaction_id'], capture.params["approval"], 9900, auth.params["token"]].join(";"), capture.authorization

    # linked to a specific transaction_id
    assert refund = @gateway.refund(9900, capture.authorization)
    assert_success refund
    assert_not_nil(refund.authorization)
    assert_not_nil(refund.params["approval"])
  end

  def test_refund_backwards_compatible
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)

    assert response = @gateway.purchase(9900, card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]

    old_authorization = [response.params['transaction_id'], response.params["approval"], 9900].join(";")

    # linked to a specific transaction_id
    assert credit = @gateway.refund(9900, old_authorization, :credit_card => card)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(response.params["approval"])
    assert_equal [response.params['transaction_id'], response.params["approval"], 9900, response.params["token"]].join(";"), response.authorization
  end

  def test_credit
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)

    # no link to a specific transaction_id
    assert credit = @gateway.credit(9900, card)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(credit.params["approval"])
  end

  def test_failed_capture
    assert response = @gateway.capture(9900, '7605f7c5d6e8f74deb')
    assert_failure response
    assert_equal 'Transaction Not Found.', response.message
  end

  def test_invalid_login
    gateway = JetpayGateway.new(:login => 'bogus')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response

    assert_equal 'Bad Terminal ID.', response.message
  end

  def test_missing_login
    gateway = JetpayGateway.new(:login => '')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response

    assert_equal 'No response returned (missing credentials?).', response.message
  end

  def test_transcript_scrubbing
    @amount = 9900
    @credit_card.verification_value = "421"
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
