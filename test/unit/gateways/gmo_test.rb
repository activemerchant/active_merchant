require 'test_helper'

class GmoTest < Test::Unit::TestCase
  def setup
    @gateway = GmoGateway.new(
                 :login => 'demo',
                 :password => 'password'
               )

    @credit_card = credit_card('4111111111111111')
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    s = sequence("successful_purchase")
    @gateway.expects(:ssl_post).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal '3d4d68331d1c6335fb679a251d6fc195-07f7fbf0a729b8089947ab4e1a4adae1', response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_unsuccessful_purchase
    s = sequence("unsuccessful_purchase")
    @gateway.expects(:ssl_post).returns(failed_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(failed_purchase_response[1]).in_sequence(s)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response

    assert_equal 'Card limit has been exceeded', response.message
    assert response.test?
  end

  def test_unsuccessful_purchase_2
    @gateway.expects(:ssl_post).returns(failed_purchase_response_2)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response

    assert_equal 'Order ID previously used', response.message
    assert response.test?
  end

  def test_successful_authorize
    s = sequence("successful_authorize")
    @gateway.expects(:ssl_post).returns(successful_authorize_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_authorize_response[1]).in_sequence(s)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal '3d4d68f3ad1c6335fb679a251d6fc195-07f7fbf0a729b8019947a04e1a4adae1', response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_unsuccessful_authorize
    s = sequence("unsuccessful_authorize")
    @gateway.expects(:ssl_post).returns(failed_authorize_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(failed_authorize_response[1]).in_sequence(s)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response

    assert_equal 'Card limit has been exceeded', response.message
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, '3d4d62111d1c6365fb679a251d6fc195-07f511f0a729b8089943af4e1a4adae1', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '3d4d62111d1c6365fb679a251d6fc195-07f511f0a729b8089943af4e1a4adae1', response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(@amount, '4f4d62171d1c6365fb679a251d6fc195-17f981f0a729b8089943af4e152adae1', @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Transaction authorization is too old', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae1', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae1', response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void('123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae9', @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Access ID and Password are invalid', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@amount, '123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae1', @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae1', response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(101, '123d62191d1c6365fb679a251d6fc195-59a511f0a729b8089943af4e1a4adae1', @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'Amount is outside valid range', response.message
    assert response.test?
  end

  private

  def successful_purchase_response
    [
      "AccessID=3d4d68331d1c6335fb679a251d6fc195&AccessPass=07f7fbf0a729b8089947ab4e1a4adae1",
      "ACS=0&OrderID=1&Forward=2a99661&Method=1&PayTimes=&Approve=0000011&TranID=1905225193602257200976416673&TranDate=20140529101010&CheckString=eef285352ce3f592c7d13d096949c230"
    ]
  end

  def failed_purchase_response
    [
      "AccessID=3d4d68331d1c6335fb679a251d6fc195&AccessPass=07f7fbf0a729b8089947ab4e1a4adae1",
      "ErrCode=G55&ErrInfo=42G550000"
    ]
  end

  def failed_purchase_response_2
    "ErrCode=E01&ErrInfo=E01040010"
  end

  def successful_authorize_response
    [
      "AccessID=3d4d68f3ad1c6335fb679a251d6fc195&AccessPass=07f7fbf0a729b8019947a04e1a4adae1",
      "ACS=0&OrderID=1&Forward=2a99661&Method=1&PayTimes=&Approve=0000011&TranID=6905525193632257200976416679&TranDate=20140602101010&CheckString=3a81a334357cad7a524d8556cc412bae"
    ]
  end

  def failed_authorize_response
    [
      "AccessID=3d4d68331d1c6335fb679a251d6fc195&AccessPass=07f7fbf0a729b8089947ab4e1a4adae1",
      "ErrCode=G55&ErrInfo=42G550000"
    ]
  end

  def successful_capture_response
    "AccessID=3d4d62111d1c6365fb679a251d6fc195&AccessPass=07f511f0a729b8089943af4e1a4adae1&Forward=2a99661&Approve=0000011&TranID=1404525122632257200976416679&TranDate=20140602121010"
  end

  def failed_capture_response
    "ErrCode=M01&ErrInfo=M01060010"
  end

  def successful_void_response
    "AccessID=123d62191d1c6365fb679a251d6fc195&AccessPass=59a511f0a729b8089943af4e1a4adae1&Forward=2a99661&Approve=0000011&TranID=1154525128632257200976416679&TranDate=20140602121210"
  end

  def failed_void_response
    "ErrCode=E01&ErrInfo=E01110002"
  end

  def successful_refund_response
    "AccessID=123d62191d1c6365fb679a251d6fc195&AccessPass=59a511f0a729b8089943af4e1a4adae1&Forward=2a99661&Approve=0000011&TranID=1154525128032257210976416679&TranDate=20140602131210"
  end

  def failed_refund_response
    "ErrCode=M01&ErrInfo=M01005011"
  end

end
