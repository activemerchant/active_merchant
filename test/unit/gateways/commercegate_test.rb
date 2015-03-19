require 'test_helper'

class CommercegateTest < Test::Unit::TestCase
  def setup
    @gateway = CommercegateGateway.new(
      login: 'usrID',
      password: 'usrPass',
      site_id: '123',
      offer_id: '321'
    )

    @credit_card = credit_card

    @amount = 1000

    @options = {
      address: address
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291387', response.authorization
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'S', response.cvv_result["code"]
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, '100130291387', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291402', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291412', response.authorization
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'S', response.cvv_result["code"]
    assert_equal 'rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz', response.params['token']
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount, '100130291387', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291425', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']
  end


  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void('100130291412', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130425094', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response_invalid_country)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-103', response.params['returnCode']
  end

  def test_unsuccessful_capture_empty_trans_id
    @gateway.expects(:ssl_post).returns(failed_request_response)
    assert response = @gateway.capture(@amount, '', @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-125', response.params['returnCode']
  end

  def test_unsuccessful_capture_trans_id_not_found
    @gateway.expects(:ssl_post).returns(failed_capture_response_invalid_trans_id)
    assert response = @gateway.capture(@amount, '', @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-121', response.params['returnCode']
  end

  private

  def failed_request_response
    "returnCode=-125&returnText=Invalid+operation"
  end

  def successful_purchase_response
    "action=SALE&returnCode=0&returnText=Success&authCode=040404&avsCode=U&cvvCode=S&amount=10.00&currencyCode=EUR&transID=100130291412&token=rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz"
  end

  def successful_authorize_response
    "action=AUTH&returnCode=0&returnText=Success&authCode=726293&avsCode=U&cvvCode=S&amount=10.00&currencyCode=EUR&transID=100130291387&token=Hf4lDYcKdJsdX92WJ2CpNlEUdh05utsI"
  end

  def failed_authorize_response_invalid_country
    "action=AUTH&returnCode=-103&returnText=Invalid+country"
  end

  def successful_capture_response
    "action=CAPTURE&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130291402"
  end

  def failed_capture_response_invalid_trans_id
    "action=CAPTURE&returnCode=-121&returnText=Previous+transaction+not+found"
  end

  def successful_refund_response
    "action=REFUND&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130291425"
  end

  def successful_void_response
    "action=VOID_AUTH&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130425094"
  end
end
