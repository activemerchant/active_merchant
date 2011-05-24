require 'test_helper'

class RemoteIdealRabobankTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = IdealRabobankGateway.new(fixtures(:ideal_rabobank))

    @options = {
      :issuer_id     => '0151',
      :return_url    => 'http://www.return.url',
      :order_id      => '1234567890123456',
      :currency      => 'EUR',
      :description   => 'A description',
      :entrance_code => '1234'
    }
  end

  def test_issuers
    response = @gateway.issuers
    list = response.issuer_list

    assert_equal 3, list.length
    assert_equal 'Test Issuer', list[0]['issuerName']
    assert_equal '0121', list[0]['issuerID']
    assert_equal 'Short', list[0]['issuerList']
  end


  def test_set_purchase
    response = @gateway.setup_purchase(550, @options)

    assert_success response
    assert response.test?
    assert_nil response.error, "Response should not have an error"
  end

  def test_return_errors
    response = @gateway.setup_purchase(0.5, @options)
    assert_failure response
    assert_equal 'BR1210', response.error[ 'errorCode']
    assert_not_nil response.error['errorMessage'],   "Response should contain an Error message"
    assert_not_nil response.error['errorDetail'],    "Response should contain an Error Detail message"
    assert_not_nil response.error['consumerMessage'],"Response should contain an Consumer Error message"
  end

  # default payment should succeed
  def test_purchase_successful
    response = @gateway.setup_purchase(100, @options)

    assert_success response

    assert_equal '1234567890123456', response.transaction['purchaseID']
    assert_equal '0020', response.params['AcquirerTrxRes']['Acquirer']['acquirerID']
    assert_not_nil response.service_url, "Response should contain a service url for payment"

    # now authorize the payment, issuer simulator has completed the payment
    response = @gateway.capture(response.transaction['transactionID'])

    assert_success response
    assert_equal 'Success', response.transaction['status']
    assert_equal 'DEN HAAG', response.transaction['consumerCity']
    assert_equal "Hr J A T Verf\303\274rth en/of Mw T V Chet", response.transaction['consumerName']
  end

  # payment of 200 should cancel
  def test_purchase_cancel
    response = @gateway.setup_purchase(200, @options)

    assert_success response
    # now try to authorize the payment, issuer simulator has cancelled the payment
    response = @gateway.capture(response.transaction['transactionID'])

    assert_failure response
    assert_equal 'Cancelled', response.transaction['status'], 'Transaction should cancel'
  end

  # payment of 300 should expire
  def test_transaction_expired
    response = @gateway.setup_purchase(300, @options)

    # now try to authorize the payment, issuer simulator let the payment expire
    response = @gateway.capture(response.transaction['transactionID'])

    assert_failure response
    assert_equal 'Expired', response.transaction['status'], 'Transaction should expire'
  end

  # payment of 400 should remain open
  def test_transaction_opened
    response = @gateway.setup_purchase(400, @options)

    # now try to authorize the payment, issuer simulator keeps the payment open
    response = @gateway.capture(response.transaction['transactionID'])

    assert_failure response
    assert_equal 'Open', response.transaction['status'], 'Transaction should remain open'
  end

  # payment of 500 should fail at issuer
  def test_transaction_failed
    response = @gateway.setup_purchase(500, @options)

    # now try to authorize the payment, issuer simulator lets the payment fail
    response = @gateway.capture(response.transaction['transactionID'])
    assert_failure response
    assert_equal 'Failure', response.transaction['status'], 'Transaction should fail'
  end

  # payment of 700 should be unknown at issuer
  def test_transaction_unknown
    response = @gateway.setup_purchase(700, @options)

    # now try to authorize the payment, issuer simulator lets the payment fail
    response = @gateway.capture(response.transaction['transactionID'])

    assert_failure response
    assert_equal 'SO1000', response.error[ 'errorCode'], 'ErrorCode should be correct'
  end

end
