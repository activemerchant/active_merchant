require 'test_helper'

class NetaxeptTest < Test::Unit::TestCase
  def setup
    @gateway = NetaxeptGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1'
    }
  end
  
  def test_successful_purchase
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of NetaxeptGateway::Response, response
    assert_success response
    
    assert_equal '16ea6a9d9253129ea5d70513093afe33', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(failed_purchase_response).in_sequence(s)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    
    assert_equal '16ea6a9d9253129ea5d70513093afe33', response.authorization
    assert response.test?
  end

  def test_requires_order_id
    assert_raise(ArgumentError) do
      response = @gateway.purchase(@amount, @credit_card, {})
    end
  end
  
  def test_handles_currency_with_money
    s = sequence("request")
    @gateway.expects(:ssl_get ).with(regexp_matches(/currencyCode=USD/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert_success @gateway.purchase(100, @credit_card, @options.merge(:currency => 'USD'))
  end
  
  def test_handles_currency_with_option
    s = sequence("request")
    @gateway.expects(:ssl_get ).with(regexp_matches(/currencyCode=USD/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert_success @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'USD'))
  end
  
  def test_handles_visa_card_type
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).with(anything,
      all_of(regexp_matches(/va=/), 
             regexp_matches(/vm=/),
             regexp_matches(/vy=/),
             regexp_matches(/vc=/))).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end
  
  def test_handles_master_card_type
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).with(anything,
      all_of(regexp_matches(/ma=/), 
             regexp_matches(/mm=/),
             regexp_matches(/my=/),
             regexp_matches(/mc=/))).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert_success @gateway.purchase(@amount, credit_card('1', :brand => 'master'), @options)
  end
  
  def test_handles_amex_card_type
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).with(anything,
      all_of(regexp_matches(/aa=/), 
             regexp_matches(/am=/),
             regexp_matches(/ay=/),
             regexp_matches(/ac=/))).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    assert_success @gateway.purchase(@amount, credit_card('1', :brand => 'american_express'), @options)
  end
  
  def test_invalid_card_type
    assert_raise(ArgumentError) do
      @gateway.purchase(@amount, credit_card('1', :brand => 'discover'), @options)
    end
  end
  
  def test_handles_setup_transaction_error
    @gateway.expects(:ssl_get ).returns(error_purchase_response[0])
    @gateway.expects(:ssl_post).never
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_handles_process_setup_error
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(error_purchase_response[2]).in_sequence(s)
    
    assert response = @gateway.purchase(@amount, credit_card(''), @options)
    assert_failure response
    assert_equal 'Unable to process setup', response.message
    assert_equal '137:7', response.error_detail
  end

  def test_handles_transaction_error
    s = sequence("request")
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(error_purchase_response[3]).in_sequence(s)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Missing parameter: 'Transaction Amount'", response.message
    assert_nil response.error_detail
  end

  def test_uses_credit_card_brand_instead_of_credit_card_type
    brand = @credit_card.brand
    @credit_card.expects(:type).never
    @credit_card.expects(:brand).at_least_once.returns(brand)

    @gateway.send(:add_creditcard, {}, @credit_card)
  end
  
  def test_url_escape_password
    @gateway = NetaxeptGateway.new(:login => 'login', :password => '1a=W+Yr2')
    
    s = sequence("request")
    @gateway.expects(:ssl_get).with(regexp_matches(/token=1a%3DW%2BYr2/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    @gateway.purchase(@amount, @credit_card, @options)
  end
  
  def test_using_credit_card_transaction_service_type
    s = sequence("request")
    @gateway.expects(:ssl_get ).with(regexp_matches(/serviceType=M/)).returns(successful_purchase_response[0]).in_sequence(s)
    @gateway.expects(:ssl_post).returns(successful_purchase_response[1]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[2]).in_sequence(s)
    @gateway.expects(:ssl_get ).returns(successful_purchase_response[3]).in_sequence(s)
    
    @gateway.purchase(@amount, @credit_card, @options)
  end
  
  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    [
      %(<?xml version="1.0"?>
        <SetupResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <SetupString>IYICvFqCArg8TVNHKzYrU2lnRGF0I1ZFUis1KzIuMC4yI1NZUyszK1BPUyNDSUQrMjArNWJkYjBkYjQ2MDI5NDljNDhmYWUjVElNKzEwKzEwMDM5NzMwNzUjREFUKzI0NCtRZ3BOUWk0d01ESXVNVFk0UndZeU1EQTVNRFpJQTA1UFMwc0dOVGM0TWpBd1RpQXhObVZoTm1FNVpEa3lOVE14TWpsbFlUVmtOekExTVRNd09UTmhabVV6TTFJRE1UQXdWUTR5TURFd01ESXdPREl4TVRjMU5WY2dPV0k0TmpjME5EVTNZemM1WldJek9EWXdaVGt3TWpVNFpqUTNNVGM1TWpaZk5RRXpYejBOTGs1RlZDQlFMMGx1ZG05clpWK0JBQUVnWDRFQkVtaDBkSEE2THk5bGVHRnRjR3hsTG1OdmJWK0JNQWd4TURBd01ESTBNdz09I1A3UyszNTIrTUlJQkFnWUpLb1pJaHZjTkFRY0NvSUgwTUlIeEFnRUJNUXN3Q1FZRkt3NERBaG9GQURBakJna3Foa2lHOXcwQkJ3R2dGZ1FVT3Y0SE1pNU9YR2QwOThhNGFMaFhJSGxVcW9JeGdia3dnYllDQVFPQUZDZTdYRmRQdlg0NS9lTDcxaFI2QjB2Y2ZreThNQWtHQlNzT0F3SWFCUUF3RFFZSktvWklodmNOQVFFQkJRQUVnWUNEZ1ZwVVVFZ1p1clEyQUpOL2tYNTh3VVo2bE9qcjZsTldVZnhJZ1R5NHJCcytPcGxFRHI5MFRhajNOK0o4YzNZanVxY3Z4ZzhRYysrbDQ4WE9GSlcyMzZRQWtlMENqeDAxcmY2RFUzOEhjcDR2aFpzdUpsZTFGUjNuT2hrNUtDNHZQcGVWNHFrOXBxZzZCblo3L1BVUkU3a0w1akVhN0dsVkxJcSthdXpnT0E9PT4=</SetupString>
        </SetupResponse>),
      %(IYIChFqCAoA8TVNHKzYrU2lnRGF0I1ZFUis1KzIuMC4yI1NZUyszK1BPUyNDSUQrMjArNWJkYjBkYjQ2MDI5NDljNDhmYWUjVElNKzEwKzEwMDM5NzMwNzcjREFUKzE4OCtRZ3BOUWk0d01ESXVNVFk0UndZeU1EQTVNRFpMQmpVM09ESXdNRTRnTVRabFlUWmhPV1E1TWpVek1USTVaV0UxWkRjd05URXpNRGt6WVdabE16TlZEakl3TVRBd01qQTRNakV4TnpVM1hnSlBTMThoQVROZkxnTTFOemhmUFEwdVRrVlVJRkF2U1c1MmIydGxYNEViQWs1UFg0RWtEVFkwTGpJeU15NHlNakV1TnpsZmdTVUVNVEV3T1E9PSNQN1MrMzUyK01JSUJBZ1lKS29aSWh2Y05BUWNDb0lIME1JSHhBZ0VCTVFzd0NRWUZLdzREQWhvRkFEQWpCZ2txaGtpRzl3MEJCd0dnRmdRVURidW1CNVJBeGJXTmV0bHFrWjc5dnp5RUtxY3hnYmt3Z2JZQ0FRT0FGQ2U3WEZkUHZYNDUvZUw3MWhSNkIwdmNma3k4TUFrR0JTc09Bd0lhQlFBd0RRWUpLb1pJaHZjTkFRRUJCUUFFZ1lCQTNSNE9oZjlHWlhhNUtYb1k3Yi9BK0wxaUxhQjB2U3c2b1RDN1FPaytmYUtOZFlsb0VOQTJBaUo1eFhUOTlINzhPdGhVWTM5WnhXdy9HYjR4K1cwZi81UnBNVlI0bC9SaDY5d0ZUUjczNjN3SDBRVm9NSmRZUkhlNFRjN1NZSzQvNnJYbno3MHlHcDZyYVFDQ1Y3QndTeHhYSThRY3M1clFiUiszVUFVMStnPT0+),
      %(<?xml version="1.0"?>
        <Result xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <IssuerId>3</IssuerId>
          <ResponseCode>OK</ResponseCode>
          <TransactionId>16ea6a9d9253129ea5d70513093afe33</TransactionId>
          <IssuerCountryCode>578</IssuerCountryCode>
          <IssuerCountry>NO</IssuerCountry>
          <ExecutionTime>2010-02-08T21:18:03.89875+01:00</ExecutionTime>
          <MerchantId>200906</MerchantId>
          <CustomerIP>64.223.221.79</CustomerIP>
          <CardExpiryDate>1109</CardExpiryDate>
        </Result>),
      %(<?xml version="1.0"?>
        <Result xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <SessionNumber>156</SessionNumber>
          <IssuerId>3</IssuerId>
          <AuthorizationId>100090</AuthorizationId>
          <ResponseCode>OK</ResponseCode>
          <TransactionId>16ea6a9d9253129ea5d70513093afe33</TransactionId>
          <ExecutionTime>2010-02-08T21:18:04.89875+01:00</ExecutionTime>
          <MerchantId>10000243</MerchantId>
        </Result>),
    ]
  end
  
  # Place raw failed response from gateway here
  def error_purchase_response
    [
      %(<?xml version="1.0"?>
      <GenericError xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <Message>Unable to translate supermerchant to submerchant, please check currency code and merchant ID</Message>
      </GenericError>),
      nil,
      %(<?xml version="1.0"?>
      <BBSException xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <Message>Unable to process setup</Message>
        <Result>
          <ResponseCode>01</ResponseCode>
          <ResponseText>137:7</ResponseText>
          <ResponseSource>05</ResponseSource>
          <TransactionId>3548b44bdf7a944aac19122ee44447c5</TransactionId>
          <ExecutionTime>2010-02-08T22:33:01.758125+01:00</ExecutionTime>
          <MerchantId>200906</MerchantId>
          <CustomerIP>64.223.221.79</CustomerIP>
        </Result>
      </BBSException>),
      %(<?xml version="1.0"?>
      <ValidationException xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <Message>Missing parameter: 'Transaction Amount'</Message>
      </ValidationException>)
    ]
  end
  
  def failed_purchase_response
    %(<?xml version="1.0"?>
    <BBSException xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <Message>Unable to sale</Message>
      <Result>
        <IssuerId>3</IssuerId>
        <ResponseCode>99</ResponseCode>
        <ResponseText>Auth Reg Comp Failure (4925000000000087)</ResponseText>
        <ResponseSource>01</ResponseSource>
        <TransactionId>1439602190e2da1d8efa3ecefdcf2e1e</TransactionId>
        <ExecutionTime>2010-02-08T22:45:39.93+01:00</ExecutionTime>
        <MerchantId>200906</MerchantId>
      </Result>
    </BBSException>)
  end
end
