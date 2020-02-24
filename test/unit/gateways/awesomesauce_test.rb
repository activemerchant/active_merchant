require 'test_helper'

class AwesomesauceTest < Test::Unit::TestCase
  def setup
    @gateway = AwesomesauceGateway.new(fixtures(:awesomesauce))
    @credit_card = credit_card('4111111111111111')
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "purchDjvHxq-5", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal "authmjMJxlfN", response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal "capU1ebFBaV", response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response

    assert_equal "cancelnDbfHZpC", response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(auth.authorization,@options)
    assert_success response

    assert_equal "cancelhpOUC8i6", response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("")
    assert_failure response
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_verify_response)

    response = @gateway.verify(100, @credit_card, @options)
    assert_success response

    assert_equal "cancelYSRwsh91", response.authorization
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(100,@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(103, @credit_card, @options)
    assert_failure response
  end

  # def test_scrub
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  private

  def pre_scrubbed
    %q(
      
    )
  end

  # def post_scrubbed
  #   %q(
  #     Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
  #     Things to scrub:
  #       - Credit card number
  #       - CVV
  #       - Sensitive authentication details
  #   )
  # end

  def successful_purchase_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"purchDjvHxq-5\",\"amount\":\"1.00\"}
    RESPONSE
    
      # Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      # to "true" when running remote tests:

      # $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
      #   test/remote/gateways/remote_awesomesauce_test.rb \
      #   -n test_successful_purchase
  
  end

  def failed_purchase_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"purcherr01miPh4HdM\",\"error\":\"01\"}
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"authmjMJxlfN\",\"amount\":\"1.00\"}
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"autherr01aJaNSN3l\",\"error\":\"01\"}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"capU1ebFBaV\"}
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"caperr10kUhcjaSn\",\"error\":\"10\"}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"cancelnDbfHZpC\"}
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"cancelerr10nqOfsGOX\",\"error\":\"10\"}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"cancelhpOUC8i6\"}
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"cancelerr10ObsvZvBe\",\"error\":\"10\"}
    RESPONSE
  end
  
  def successful_verify_response
    <<-RESPONSE
      {\"succeeded\":true,\"id\":\"cancelYSRwsh91\"}
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
      {\"succeeded\":false,\"id\":\"autherr03ea5GFT__\",\"error\":\"03\"}
    RESPONSE
  end

end
