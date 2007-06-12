require File.dirname(__FILE__) + '/../../test_helper'

class TransFirstTest < Test::Unit::TestCase
  AMOUNT = 100

  def setup
    @gateway = TransFirstGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end
  
  def test_successful_request
    @creditcard.number = 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert response.success?
    assert_equal '5555', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @creditcard.number = 2
    assert response = @gateway.purchase(AMOUNT, @creditcard, {})
    assert !response.success?
    assert response.test?
  end

  def test_request_error
    @creditcard.number = 3
    assert_raise(Error){ @gateway.purchase(AMOUNT, @creditcard, {}) }
  end
  
  def test_missing_field_response
    @gateway.stubs(:ssl_post).returns(missing_field_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard)
    
    assert !response.success?
    assert response.test?
    assert_equal 'Missing parameter: UserId.', response.message
  end
  
  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard)
    
    assert response.success?
    assert response.test?
    assert_equal 'test transaction', response.message
    assert_equal '355', response.authorization
  end
  
  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(AMOUNT, @creditcard)
    
    assert !response.success?
    assert response.test?
    assert_equal '29005716', response.authorization
    assert_equal 'Invalid cardholder number', response.message
  end
  
  private
  def missing_field_response
    "Missing parameter: UserId.\r\n"
  end
  
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?> 
<CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/"> 
  <TransID>355</TransID> 
  <RefID>c2535abbf0bb38005a14fd575553df65</RefID> 
  <Amount>1.00</Amount> 
  <AuthCode>Test00</AuthCode> 
  <Status>Authorized</Status> 
  <AVSCode /> 
  <Message>test transaction</Message> 
  <CVV2Code /> 
  <ACI /> 
  <AuthSource /> 
  <TransactionIdentifier /> 
  <ValidationCode /> 
  <CAVVResultCode /> 
</CCSaleDebitResponse>
    XML
  end
  
  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>  
<CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/"> 
  <TransID>29005716</TransID> 
  <RefID>0610</RefID>  
  <PostedDate>2005-09-29T15:16:23.7297658-07:00</PostedDate>  
  <SettledDate>2005-09-29T15:16:23.9641468-07:00</SettledDate>  
  <Amount>0.02</Amount>  
  <AuthCode />  
  <Status>Declined</Status>  
  <AVSCode />  
  <Message>Invalid cardholder number</Message>  
  <CVV2Code />  
  <ACI />  
  <AuthSource />  
  <TransactionIdentifier />  
  <ValidationCode />  
  <CAVVResultCode />  
</CCSaleDebitResponse>
    XML
  end
end
