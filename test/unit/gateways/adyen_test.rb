require 'test_helper'

class AdyenTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenGateway.new(
      company: 'company',
      merchant: 'merchant',
      password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_authorize
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '7914002629995504', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.stubs(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.stubs(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '7914002629995504', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '500', :body => failed_capture_response)))

    response = @gateway.capture(@amount, '0000000000000000', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '7914002629995504', @options)
    assert_success response
    assert response.test?

  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).raises(ActiveMerchant::ResponseError.new(stub(:code => '500', :body => failed_refund_response)))

    response = @gateway.refund(@amount, '0000000000000000', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('7914002629995504', @options)
    assert_success response
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "Refused", response.message
  end

  def test_fractional_currency
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:post_data).with do |params|
      assert_equal '100', params['paymentRequest.amount.value']
      assert_equal 'JPY', params['paymentRequest.amount.currency']
    end

    @options[:currency] = 'JPY'

    @gateway.authorize(@amount, @credit_card, @options)
  end

  private

  def successful_authorize_response
    'paymentResult.pspReference=7914002629995504&paymentResult.authCode=56469&paymentResult.resultCode=Authorised'
  end

  def failed_authorize_response
    'paymentResult.pspReference=7914002630895750&paymentResult.refusalReason=Refused&paymentResult.resultCode=Refused'
  end

  def successful_capture_response
    'modificationResult.pspReference=8814002632606717&modificationResult.response=%5Bcapture-received%5D'
  end

  def failed_capture_response
    'validation 100 No amount specified'
  end

  def successful_refund_response
    'modificationResult.pspReference=8814002634988063&modificationResult.response=%5Brefund-received%5D'
  end

  def failed_refund_response
    'validation 100 No amount specified'
  end

  def successful_void_response
    'modificationResult.pspReference=7914002636728161&modificationResult.response=%5Bcancel-received%5D'
  end
end
