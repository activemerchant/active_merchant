require 'test_helper'

class ZeusTest < Test::Unit::TestCase
  def setup
    @gateway = ZeusGateway.new(clientip: '0000000000')

    @credit_card = credit_card
    @amount = 100

    @options = {
      telno: '9999999999',
      sendid: 'fake_id'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal nil, response.authorization
    assert_equal nil, response.error_code
    assert response.test?
  end

  def test_successful_purchase_with_order
    @gateway.expects(:ssl_post).returns(successful_purchase_response_with_order)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'TEST-Fake-Order-1', response.authorization
    assert_equal nil, response.error_code
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal nil, response.authorization
    assert_equal 'failure_order', response.error_code
    assert response.test?
  end

  def test_failed_purchase_with_order
    @gateway.expects(:ssl_post).returns(failed_purchase_response_with_order)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'TEST-Fake-order-2', response.authorization
    assert_equal 'failure_order', response.error_code
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, 'TEST-Fake-Order-1', Date.today.to_s.gsub('-', ''))

    assert_success response
    assert_equal 'TEST-Fake-Order-1', response.authorization
    assert_equal nil, response.error_code
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, 'TEST-Invalid-Order', Date.today.to_s.gsub('-', ''))

    assert_failure response
    assert_equal 'TEST-Invalid-Order', response.authorization
    assert_equal 'failer_order', response.error_code
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.authorize(@amount, 'TEST-Fake-Order-1', Date.today.to_s.gsub('-', ''))

    assert_success response
    assert_equal 'TEST-Fake-Order-1', response.authorization
    assert_equal nil, response.error_code
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.authorize(@amount, 'TEST-Invalid-Order', Date.today.to_s.gsub('-', ''))

    assert_failure response
    assert_equal 'TEST-Invalid-Order', response.authorization
    assert_equal 'failer_order', response.error_code
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund('TEST-Fake-Order-1')

    assert_success response
    assert_equal "0 -", response.params['status']
    assert_equal 'TEST-Fake-Order-1', response.authorization
    assert_equal nil, response.error_code
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund('TEST-Invalid-Order')

    assert_failure response
    assert_equal "0 1", response.params['status']
    assert_equal 'TEST-Invalid-Order', response.authorization
    assert_equal 'failure_order', response.error_code
    assert response.test?
  end

  private

    def successful_purchase_response
      'Success_order'
    end

    def successful_purchase_response_with_order
      "Success_order\nTEST-Fake-Order-1"
    end

    def failed_purchase_response
      'failure_order'
    end

    def failed_purchase_response_with_order
      "failure_order\nTEST-Fake-order-2"
    end

    def successful_authorize_response
      "Success_order"
    end

    def failed_authorize_response
      'failer_order'
    end

    def successful_capture_response
      "Success_order"
    end

    def failed_capture_response
      "failer_order"
    end

    def successful_refund_response
      "0 -\n\nSuccessOK\n\n"
    end

    def failed_refund_response
      "0 1\n\nfailure_order\n\n"
    end

end
