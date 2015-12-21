require 'test_helper'

class SageBankcardGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SageBankcardGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED", response.message
    assert_equal "1234567890;bankcard", response.authorization

    assert_equal "A",                  response.params["success"]
    assert_equal "911911",             response.params["code"]
    assert_equal "APPROVED",           response.params["message"]
    assert_equal "00",                 response.params["front_end"]
    assert_equal "M",                  response.params["cvv_result"]
    assert_equal "X",                  response.params["avs_result"]
    assert_equal "00",                 response.params["risk"]
    assert_equal "1234567890",         response.params["reference"]
    assert_equal "1000",               response.params["order_number"]
    assert_equal "0",                  response.params["recurring"]
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED 000001", response.message
    assert_equal "B5O89VPdf0;bankcard", response.authorization

    assert_equal "A",                    response.params["success"]
    assert_equal "000001",               response.params["code"]
    assert_equal "APPROVED 000001",      response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "M",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "B5O89VPdf0",           response.params["reference"]
    assert_equal "e81cab9e6144a160da82", response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_declined_purchase
    @gateway.expects(:ssl_post).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal "DECLINED", response.message
    assert_equal "A5O89kkix0;bankcard", response.authorization

    assert_equal "E",                    response.params["success"]
    assert_equal "000002",               response.params["code"]
    assert_equal "DECLINED",             response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "N",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "A5O89kkix0",           response.params["reference"]
    assert_equal "3443d6426188f8256b8f", response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, "A5O89kkix0")
    assert_instance_of Response, response
    assert_success response

    assert_equal "APPROVED 000001", response.message
    assert_equal "B5O8AdFhu0;bankcard", response.authorization

    assert_equal "A",                    response.params["success"]
    assert_equal "000001",               response.params["code"]
    assert_equal "APPROVED 000001",      response.params["message"]
    assert_equal "10",                   response.params["front_end"]
    assert_equal "P",                    response.params["cvv_result"]
    assert_equal "",                     response.params["avs_result"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "B5O8AdFhu0",           response.params["reference"]
    assert_equal "ID5O8AdFhw",           response.params["order_number"]
    assert_equal "0",                    response.params["recurring"]
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, "Authorization")
    assert_success response
    assert_equal "G68FCU2c60;bankcard", response.authorization
    assert_equal "APPROVED", response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "Authorization")
    assert_failure response
    assert_equal "INVALID T_REFERENCE", response.message
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal "SECURITY VIOLATION", response.message
    assert_equal "0000000000;bankcard", response.authorization

    assert_equal "X",                  response.params["success"]
    assert_equal "911911",             response.params["code"]
    assert_equal "SECURITY VIOLATION", response.params["message"]
    assert_equal "00",                 response.params["front_end"]
    assert_equal "P",                  response.params["cvv_result"]
    assert_equal "",                   response.params["avs_result"]
    assert_equal "00",                 response.params["risk"]
    assert_equal "0000000000",         response.params["reference"]
    assert_equal "",                   response.params["order_number"]
    assert_equal "0",                  response.params["recurring"]
  end

  def test_include_customer_number_for_numeric_values
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({:customer => "123"}))
    end.check_request do |method, data|
      assert data =~ /T_customer_number=123/
    end.respond_with(successful_authorization_response)
  end

  def test_dont_include_customer_number_for_numeric_values
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({:customer => "bob@test.com"}))
    end.check_request do |method, data|
      assert data !~ /T_customer_number/
    end.respond_with(successful_authorization_response)
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_us_address_with_state
    post = {}
    options = {
      :billing_address => { :country => "US", :state => "CA"}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "US", post[:C_country]
    assert_equal "CA", post[:C_state]
  end

  def test_us_address_without_state
    post = {}
    options = {
      :billing_address => { :country => "US", :state => ""}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "US", post[:C_country]
    assert_equal "", post[:C_state]
  end


  def test_international_address_without_state
    post = {}
    options = {
      :billing_address => { :country => "JP", :state => ""}
    }
    @gateway.send(:add_addresses, post, options)

    assert_equal "JP", post[:C_country]
    assert_equal "Outside of United States", post[:C_state]
  end

  private
  def successful_authorization_response
    "\002A911911APPROVED                        00MX001234567890\0341000\0340\034\003"
  end

  def successful_purchase_response
    "\002A000001APPROVED 000001                 10M 00B5O89VPdf0\034e81cab9e6144a160da82\0340\034\003"
  end

  def successful_capture_response
    "\002A000001APPROVED 000001                 10P 00B5O8AdFhu0\034ID5O8AdFhw\0340\034\003"
  end

  def declined_purchase_response
    "\002E000002DECLINED                        10N 00A5O89kkix0\0343443d6426188f8256b8f\0340\034\003"
  end

  def successful_refund_response
    "\x02A      APPROVED                        10P 00G68FCU2c60\x1C16119318c1edb9a27f70\x1C0\x1C\x03"
  end

  def failed_refund_response
    "\x02X900022INVALID T_REFERENCE             00P 00G68FCVJd10\x1C72bf690488cf72c81120\x1C0\x1C\x03"
  end

  def invalid_login_response
    "\002X911911SECURITY VIOLATION              00P 000000000000\034\0340\034\003"
  end
end
