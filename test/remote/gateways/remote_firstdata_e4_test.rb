require 'test_helper'

class RemoteFirstdataE4Test < Test::Unit::TestCase
  def setup
    @gateway = FirstdataE4Gateway.new(fixtures(:firstdata_e4))
    @credit_card = credit_card
    @bad_credit_card = credit_card('4111111111111113')
    @amount = 100
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    @options_with_authentication_data = @options.merge({
      eci: "5",
      cavv: "TESTCAVV",
      xid: "TESTXID"
    })
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_card_authentication
    assert response = @gateway.purchase(@amount, @credit_card, @options_with_authentication_data)
    assert_equal response.params["cavv"], @options_with_authentication_data[:cavv]
    assert_equal response.params["ecommerce_flag"], @options_with_authentication_data[:eci]
    assert_equal response.params["xid"], @options_with_authentication_data[:xid]
    assert_success response
  end

  def test_unsuccessful_purchase
    # ask for error 13 response (Amount Error) via dollar amount 5,000 + error
    @amount = 501300
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Transaction Normal/, response.message)
    assert_failure response
  end

  def test_bad_creditcard_number
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_match(/Invalid Credit Card/, response.message)
    assert_failure response
  end

  def test_trans_error
    # ask for error 42 (unable to send trans) as the cents bit...
    @amount = 500042
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Unable to Send Transaction/, response.message) # 42 is 'unable to send trans'
    assert_failure response
  end

  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
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

    assert_equal "Transaction Normal - Approved", response.message
    assert_equal "0.0", response.params["dollar_amount"]
    assert_equal "05", response.params["transaction_type"]
  end

  def test_failed_verify
    assert response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{Invalid Credit Card Number}, response.message
  end

  def test_invalid_login
    gateway = FirstdataE4Gateway.new(:login    => "NotARealUser",
                                     :password => "NotARealPassword" )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{Unauthorized Request}, response.message
    assert_failure response
  end

  def test_response_contains_cvv_and_avs_results
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result["code"]
    assert_equal '1', response.avs_result["code"]
  end
end
