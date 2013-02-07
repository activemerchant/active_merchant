require 'test_helper'

class NetpayTest < Test::Unit::TestCase
  def setup
    @gateway = NetpayGateway.new(
                 :store_id => '12345',
                 :login    => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 1000

    @order_id = 'C3836048-631F-112B-001E-7C08C0406975'

    @options = {
      :description => 'Store Purchase'
    }
  end

  def test_response_handler_success
    response = Struct.new(:code).new(200)
    assert_equal response, @gateway.send(:handle_response, response)
  end

  def test_response_handler_failure
    response = Struct.new(:code).new(400)
    assert_raise ActiveMerchant::ResponseError do
      @gateway.send(:handle_response, response)
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes("StoreId=12345"),
        includes("UserName=login"),
        includes("Password=password"),
        includes("ResourceName=Auth"),
        includes("Total=10.00"),
        includes("CardNumber=#{@credit_card.number}"),
        includes("ExpDate=" + CGI.escape("09/#{@credit_card.year.to_s[-2..-1]}")),
        includes("CustomerName=#{CGI.escape(@credit_card.name)}"),
        includes("CVV2=#{@credit_card.verification_value}"),
        includes("Comments=#{CGI.escape(@options[:description])}"),
        includes("CurrencyCode=484")
      )
    ).returns(successful_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of ActiveMerchant::Billing::Response, response
    assert_success response

    assert_equal "#{@order_id}|10.00|484", response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_ip
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes("IPAddress=#{CGI.escape('127.0.0.1')}")
      )
    ).returns(successful_response)

    assert response = @gateway.purchase(@amount, @credit_card, :ip => '127.0.0.1')
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end


  def test_successful_authorize
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes("StoreId=12345"),
        includes("UserName=login"),
        includes("Password=password"),
        includes("ResourceName=PreAuth"),
        includes("Total=10.00"),
        includes("CardNumber=#{@credit_card.number}"),
        includes("ExpDate=" + CGI.escape("09/#{@credit_card.year.to_s[-2..-1]}")),
        includes("CustomerName=#{CGI.escape(@credit_card.name)}"),
        includes("CVV2=#{@credit_card.verification_value}"),
        includes("Comments=#{CGI.escape(@options[:description])}"),
        includes("CurrencyCode=484")
      )
    ).returns(successful_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of ActiveMerchant::Billing::Response, response
    assert_success response
    assert_equal "#{@order_id}|10.00|484", response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes('ResourceName=PostAuth'),
        includes("Total=10.00"),
        includes("OrderId=#{@order_id}")
      )
    ).returns(successful_response)
    assert response = @gateway.capture(@amount, "#{@order_id}|10.00|484")
    assert_success response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes('ResourceName=Refund'),
        includes("Total=10.00"),
        includes("OrderId=#{@order_id}"),
        includes("CurrencyCode=484")
      )
    ).returns(successful_response)
    assert response = @gateway.void("#{@order_id}|10.00|484")
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).with(
      anything,
      all_of(
        includes('ResourceName=Credit'),
        includes("Total=10.00"),
        includes("OrderId=#{@order_id}")
      )
    ).returns(successful_response)
    assert response = @gateway.refund(@amount, "#{@order_id}|10.00|484")
    assert_success response
  end

  def test_default_currency
    assert_equal 'MXN', NetpayGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['MX'], NetpayGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express, :diners_club], NetpayGateway.supported_cardtypes
  end

  private

  # Place raw successful response from gateway here
  def successful_response
    {
      'ResponseCode' => '00',
      'ResponseMsg'  => 'Aprobada',
      'MerchantId'   => '6445472',
      'AuthCode'     => '2222222',
      'OrderId'      => @order_id,
      'TimeIn'       => '1357820939055',
      'CardTypeName' => '05',
      'IssuerAuthData' => '00000000'
    }
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {
      'ResponseCode' => '05',
      'ResponseMsg'  => 'Declinada General',
      'MerchantId'   => '6445472',
      'AuthCode'     => '000000',
      'OrderId'      => '2A770A10-1F80-95E2-54ED-96DB3BEE1B4D',
      'TimeIn'       => '1357820942291',
      'TimeOut'      => '1357820942347'
    }
  end
end
