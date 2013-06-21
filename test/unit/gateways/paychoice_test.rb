require 'test_helper'

class PaychoiceTest < Test::Unit::TestCase

  def setup
    @gateway = PaychoiceGateway.new(
      :login    => 'LOGIN',
      :password => 'PASSWORD'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => '1', :billing_address => address }
  end

  def test_new_with_login_password_creates_paychoice
    assert_instance_of PaychoiceGateway, @gateway
  end

  def test_should_have_display_name_of_just_paychoice
    assert_equal "Paychoice", PaychoiceGateway.display_name
  end

  def test_should_have_homepage_url
    assert_equal "http://www.paychoice.com.au/", PaychoiceGateway.homepage_url
  end

  def test_should_have_supported_credit_card_types
    assert_equal [:visa, :master, :american_express, :discover], PaychoiceGateway.supported_cardtypes
  end

  def test_should_have_supported_countries
    assert_equal ['AU'], PaychoiceGateway.supported_countries
  end

  def test_successful_purchase
    @gateway.expects(:purchase) # .with(@amount, @credit_card, @options)
            .returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of PaychoiceGateway::PaychoiceGatewayPurchase, response
    assert_success response

    assert_equal '769582d7-8f24-4b84-b56f-3110651f3674', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:purchase).raises(failed_purchase_response)

    assert_raise PaychoiceException do
      @gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_should_have_default_currency
    assert_equal "AUD", PaychoiceGateway.default_currency
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    PaychoiceGateway::PaychoiceGatewayPurchase.create @gateway, {"charge"=>
      {"amount"=>12.0,
       "created"=>"2013-06-04T04:16:34.95775Z",
       "error"=>"Transaction Approved",
       "error_code"=>"0",
       "id"=>"769582d7-8f24-4b84-b56f-3110651f3674",
       "link"=>
        {"href"=>"/api/v3/charge/769582d7-8f24-4b84-b56f-3110651f3674",
         "rel"=>"self"},
       "reference"=>"652298",
       "status"=>"Approved",
       "status_code"=>0},
     "object_type"=>"charge"}
  end

  def failed_purchase_response
    PaychoiceException.new("Invalid Charge")
  end
end
