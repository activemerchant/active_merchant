# encoding: utf-8
require 'test_helper'

class IyzicoTest < Test::Unit::TestCase
  def setup
    @gateway = IyzicoGateway.new(api_id: 'mrI3mIMuNwGiIxanQslyJBRYa8nYrCU5', secret: '9lkVluNHBABPw0LIvyn50oYZcrSJ8oNo')
    @credit_card = credit_card
    @declined_card = credit_card('42424242424242')
    @amount = 0.1

    @options = {
        order_id: '1',
        billing_address: address,
        shipping_address: address,
        description: 'Store Purchase',
        ip: "127.0.0.1",
        customer: 'Jim Smith',
        email: 'dharmesh.vasani@multidots.in',
        phone: '9898912233',
        name: 'Jim',
        lastLoginDate: '2015-10-05 12:43:35',
        registrationDate: '2013-04-21 15:12:09',
        items: [{
                    :name => 'EDC Marka Usb',
                    :category1 => 'Elektronik',
                    :category2 => 'Usb / Cable',
                    :id => 'BI103',
                    :price => 0.38,
                    :itemType => 'PHYSICAL',
                    :subMerchantKey => 'nm57s4v5mk2652k87g5728cc56nh23',
                    :subMerchantPrice => 0.37
                }]
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(invalid_card_number_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "5152", response.params["errorCode"]
  end

  def test_failed_purchase_with_declined_credit_card
    @gateway.expects(:ssl_post).returns(invalid_card_number_response)
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "12", response.params["errorCode"]
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end


  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(invalid_card_number_response)
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "12", response.params["errorCode"]
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    result = @gateway.authorize(@amount, @credit_card, @options)
    response = @gateway.void(result.authorization)
    assert_instance_of Response, response
    assert_success response
  end

  def test_failed_void_with_empty_payment_id
    @gateway.expects(:ssl_post).returns(invalid_signature_response)
    response = @gateway.void("", options={})
    assert_instance_of Response, response
    assert_failure response
    assert_equal "1000", response.params["errorCode"]
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    authorization = 4374
    response = @gateway.void(authorization, options={})
    assert_instance_of Response, response
    assert_failure response
    assert_equal "5088", response.params["errorCode"]
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)
    response = @gateway.verify(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)
    response = @gateway.verify(@declined_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_success response
  end

  def test_default_currency
    assert_equal 'TRY', @gateway.default_currency
  end

  def test_supported_countries
    assert_equal ['TR'], @gateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], @gateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Iyzico', @gateway.display_name
  end

  private

  def successful_purchase_response
  end

  def invalid_signature_response
    {"status"=>"failure", "errorCode"=>"1000", "errorMessage"=>"Geçersiz imza", "locale"=>"tr", "systemTime"=>1451901922908, "conversationId"=>"shopify_1"}
  end

  def invalid_card_number_response
    {"status"=>"failure",  "errorCode"=>"12", "errorMessage"=>"Kart numarası geçersizdir", "locale"=>"tr",  "systemTime"=>1451977893269, "conversationId"=>"shopify_1"}
  end

  def successful_authorize_response
  end

  def failed_authorize_response
    {"status"=>"failure", "errorCode"=>"1000", "errorMessage"=>"Geçersiz imza", "locale"=>"tr", "systemTime"=>1451898355612, "conversationId"=>"shopify_1"}
  end

  def successful_void_response
    {"status"=>"success", "locale"=>"tr", "systemTime"=>1451901238711, "paymentId"=>"4374", "price"=>0.1}
  end

  def failed_void_response
    {"status"=>"failure", "errorCode"=>"5088", "errorMessage"=>"", "locale"=>"tr", "systemTime"=>1451895765449, "conversationId"=>"shopify_1"}
  end

end
