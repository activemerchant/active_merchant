require 'test_helper'

class QuickpayV10Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = QuickpayGateway.new(:api_key => 'APIKEY')
    @credit_card = credit_card('4242424242424242')
    @amount = 100
    @options = { :order_id => '1', :billing_address => address }
  end
  
  def test_unsuccessful_payment
    @gateway.expects(:ssl_post).returns(failed_payment_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.authorization.blank?
    assert_failure response
  end
  
  def test_successful_purchase
    stub_comms do
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert response
      assert_success response
      assert_equal 1145, response.authorization
      assert response.test?
    end.respond_with(successful_payment_response, successful_authorization_response)
  end

  def test_successful_authorization
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_success response
      assert_equal 1145, response.authorization
      assert response.test?
    end.respond_with(successful_payment_response, successful_authorization_response)
  end

  def test_failed_authorization
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_failure response
      assert_equal 'Validation error', response.message
      assert response.test?
    end.respond_with(successful_payment_response, failed_authorization_response)
  end

  def test_parsing_response_with_errors
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_failure response
      assert_equal 'is not valid', response.params['errors']['id'][0]
      assert response.test?
    end.respond_with(successful_payment_response, failed_authorization_response)
  end


  def test_supported_countries
    klass = @gateway.class
    assert_equal ['DE', 'DK', 'ES', 'FI', 'FR', 'FO', 'GB', 'IS', 'NO', 'SE'], klass.supported_countries
  end

  def test_supported_card_types
    klass = @gateway.class
    assert_equal  [:dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ], klass.supported_cardtypes
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(100, 1124)
    assert_success response
  end
  
  private
  
  def successful_payment_response
    {
      "id"          =>1145, 
      "order_id"    =>"310f59c57a", 
      "accepted"    =>false, 
      "test_mode"   =>false, 
      "branding_id" =>nil, 
      "variables"   =>{}, 
      "acquirer"    =>nil, 
      "operations"  =>[], 
      "metadata"    =>{}, 
      "created_at"  =>"2015-03-30T16:56:17Z", 
      "balance"     =>0, 
      "currency"    =>"DKK"
    }.to_json
  end
  
  def successful_authorization_response
    {
       "id"          => 1145, 
       "order_id"    => "310f59c57a", 
       "accepted"    => false,
       "test_mode"   => true, 
       "branding_id" => nil, 
       "variables"   => {}, 
       "acquirer"    => "clearhaus", 
       "operations"  => [], 
       "metadata"    => {
          "type"             =>"card", 
          "brand"            =>"quickpay-test-card", 
          "last4"            =>"0008", 
          "exp_month"        =>9, 
          "exp_year"         =>2016, 
          "country"          =>"DK", 
          "is_3d_secure"     =>false, 
          "customer_ip"      =>nil, 
          "customer_country" =>nil
       }, 
      "created_at" => "2015-03-30T16:56:17Z", 
      "balance"    => 0, 
      "currency"   => "DKK"
    }.to_json  
  end

  def successful_capture_response
    {
      "id"          =>1145, 
      "order_id"    =>"310f59c57a", 
      "accepted"    =>true, 
      "test_mode"   =>true, 
      "branding_id" =>nil, 
      "variables"   =>{}, 
      "acquirer"    =>"clearhaus", 
      "operations"  =>[], 
      "metadata"    =>{"type"=>"card", "brand"=>"quickpay-test-card", "last4"=>"0008", "exp_month"=>9, "exp_year"=>2016, "country"=>"DK", "is_3d_secure"=>false, "customer_ip"=>nil, "customer_country"=>nil}, 
      "created_at"  =>"2015-03-30T16:56:17Z", 
      "balance"     =>0, 
      "currency"    =>"DKK"
    }.to_json
  end
  
  def succesful_refund_response
    {
       "id"          =>1145, 
       "order_id"    =>"310f59c57a", 
       "accepted"    =>true, 
       "test_mode"   =>true,
       "branding_id" =>nil, 
       "variables"   =>{}, 
       "acquirer"    =>"clearhaus", 
       "operations"  =>[],
       "metadata"=>{
          "type"             =>"card", 
          "brand"            =>"quickpay-test-card", 
          "last4"            =>"0008", 
          "exp_month"        =>9, 
          "exp_year"         =>2016, 
          "country"          =>"DK", 
          "is_3d_secure"     =>false, 
          "customer_ip"      =>nil, 
          "customer_country" =>nil
        },
        "created_at" =>"2015-03-30T16:56:17Z", 
        "balance"    =>100, 
        "currency"   =>"DKK"
      }.to_json  
  end
  
  def failed_authorization_response
    {
      'message' => "Validation error",
      "errors" => {
        "id" => ["is not valid"]
      }
    }.to_json
  end
  
  def failed_payment_response
    {
      "message" => "Validation error",
      "errors" => {
        "currency" => ["must be three uppercase letters"]
      },
      "error_code" => nil
    }.to_json 
  end
  

  def expected_expiration_date
    '%02d%02d' % [@credit_card.year.to_s[2..4], @credit_card.month]
  end

end
