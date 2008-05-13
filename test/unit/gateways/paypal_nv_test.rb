require File.dirname(__FILE__) + '/../../test_helper'

class PaypalNvTest < Test::Unit::TestCase
  API_VER = 50.0000
  BUILD_NUM = 1
  DEBUG_TOKEN = 1
  def setup
    Base.mode = :test
    PaypalNvGateway.pem_file = nil

    @amount = 100
    @gateway = PaypalNvGateway.new(
                :login => 'cody',
                :password => 'test',
                :pem => 'PEM'
               )

    @credit_card = credit_card('4242424242424242')
    @options = { :billing_address => address, :ip => '127.0.0.1' }
  end

  def test_no_ip_address
    assert_raise(ArgumentError){ @gateway.purchase(@amount, @credit_card, :billing_address => address)}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '9CX07910UV614511L', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_reauthorization
    @gateway.expects(:ssl_post).returns(successful_reauthorization_response)
    response = @gateway.reauthorize(@amount, '32J876265E528623B')
    assert response.success?
    assert_equal('1TX27389GX108740X', response.authorization)
    assert response.test?
  end

  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)

    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end

  def test_paypal_timeout_error
    @gateway.stubs(:ssl_post).returns(paypal_timeout_error_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "Internal Error.", response.params['l_shortmessage0']
    assert_equal "Timeout processing request.", response.params['l_longmessage0']
    assert_equal "Timeout processing request.", response.message
  end

  def test_pem_file_accessor
    PaypalNvGateway.pem_file = '123456'
    gateway = PaypalNvGateway.new(:login => 'test', :password => 'test')
    assert_equal '123456', gateway.options[:pem]
  end

  def test_passed_in_pem_overrides_class_accessor
    PaypalNvGateway.pem_file = '123456'
    gateway = PaypalNvGateway.new(:login => 'test', :password => 'test', :pem => 'Clobber')
    assert_equal 'Clobber', gateway.options[:pem]
  end

  def test_ensure_options_are_transferred_to_express_instance
    PaypalNvGateway.pem_file = '123456'
    gateway = PaypalNvGateway.new(:login => 'test', :password => 'password')
    express = gateway.express
    assert_instance_of PaypalExpressNvGateway, express
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
    assert_equal '123456', express.options[:pem]
  end

  def test_supported_countries
    assert_equal ['US'], PaypalNvGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], PaypalNvGateway.supported_cardtypes
  end

  def test_button_source
    PaypalNvGateway.application_id = 'ActiveMerchant_DC'

    data = @gateway.send(:build_sale_or_authorization_request, 'Test', @amount, @credit_card, {})
    assert_equal 'ActiveMerchant_DC', data[:buttonsource]
  end
  
  def test_tax_shipping_handling_not_added_without_subtotal
    data = @gateway.send(:build_sale_or_authorization_request, 'Authorization', @amount, @credit_card, {})
    
    assert_nil data[:itemamt]
    assert_nil data[:taxamt]
    assert_nil data[:shippingamt]
    assert_nil data[:handlingamt]
  end

  def test_adding_subtotal_adds_tax_shipping_handling
    data = @gateway.send(:build_sale_or_authorization_request, 'Authorization', @amount, @credit_card, :subtotal => 100)
    
    assert_equal '1.00', data[:itemamt]
    assert_equal '0.00', data[:taxamt]
    assert_equal '0.00', data[:shippingamt]
    assert_equal '0.00', data[:handlingamt]
  end
  
  def test_item_total_shipping_handling_and_tax
    data = @gateway.send(:build_sale_or_authorization_request, 'Authorization', @amount, @credit_card,
      :tax => @amount,
      :shipping => @amount,
      :handling => @amount,
      :subtotal => 200
    )

    assert_equal "2.00", data[:itemamt]
    assert_equal "1.00", data[:taxamt]
    assert_equal "1.00", data[:shippingamt]
    assert_equal "1.00", data[:handlingamt]
  end

  def test_should_use_test_certificate_endpoint
    gateway = PaypalNvGateway.new(
                :login => 'cody',
                :password => 'test',
                :pem => 'PEM'
              )
    assert_equal PaypalNvGateway::URLS[:test][:certificate], gateway.send(:endpoint_url)
  end

  def test_should_use_live_certificate_endpoint
    gateway = PaypalNvGateway.new(
                :login => 'cody',
                :password => 'test',
                :pem => 'PEM'
              )
    gateway.expects(:test?).returns(false)

    assert_equal PaypalNvGateway::URLS[:live][:certificate], gateway.send(:endpoint_url)
  end

  def test_should_use_test_signature_endpoint
    gateway = PaypalNvGateway.new(
                :login => 'cody',
                :password => 'test',
                :signature => 'SIG'
              )

    assert_equal PaypalNvGateway::URLS[:test][:signature], gateway.send(:endpoint_url)
  end

  def test_should_use_live_signature_endpoint
    gateway = PaypalNvGateway.new(
                :login => 'cody',
                :password => 'test',
                :signature => 'SIG'
              )
    gateway.expects(:test?).returns(false)

    assert_equal PaypalNvGateway::URLS[:live][:signature], gateway.send(:endpoint_url)
  end

  def test_should_raise_argument_when_credentials_not_present
    assert_raises(ArgumentError) do
      PaypalNvGateway.new(:login => 'cody', :password => 'test')
    end
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal '1TX27389GX108740X', response.authorization
  end
  
  def test_raise_when_greater_than_250_payment_recipients
    assert_raise(ArgumentError) do
      # You can only include up to 250 recipients
      recipients = (1..251).collect {|i| [100, "person#{i}@example.com"]}
      @gateway.transfer(*recipients)
    end
  end

  private
  def timestamp
    Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def successful_response_fields
    resp = "ACK=Success&TIMESTAMP=#{timestamp}&"
    resp << "CORRELATIONID=#{DEBUG_TOKEN}&"
    resp << "VERSION=#{API_VER}&BUILD=#{BUILD_NUM}"
  end

  def error_msg(id, code, shor, long, options = {} )
    srv_code = options[:service_code] || "000"
    err =  "&L_ERRORCODE#{id}=#{code}"
    err << "&L_SHORTMESSAGE#{id}=#{shor}"
    err << "&L_LONGMESSAGE#{id}=#{long}"
    err << "&L_SEVERITYCODE#{id}=#{srv_code}"
  end

  def error_response_fields()

    err =  "ACK=Error&TIMESTAMP=#{timestamp}"
    err << "&CORRELATIONID=#{DEBUG_TOKEN}"
    err << "&VERSION=#{API_VER}&BUILD=#{BUILD_NUM}"
  end

  def successful_purchase_response
    resp = successful_response_fields
    resp << "&AVSCODE=X&TRANSACTIONID=9CX07910UV614511L&AMT=212.95&CVV2MATCH=M"
  end

  def failed_purchase_response
    resp = error_response_fields
    resp << error_msg(0, 10418,
    "Transaction refused because of an invalid argument. See additional error messages for details.",
    "The currencies of the shopping cart amounts must be the same.")
  end


  def paypal_timeout_error_response
    resp = error_response_fields
    resp << error_msg(0, 10001,
    "Internal Error.",
    "Timeout processing request.")
  end

  def successful_reauthorization_response
    resp = successful_response_fields
    resp << "&AUTHORIZATIONID=1TX27389GX108740X"
  end

  def successful_void_response
    resp = successful_response_fields
    resp << "&AUTHORIZATIONID=1TX27389GX108740X"
  end



end
