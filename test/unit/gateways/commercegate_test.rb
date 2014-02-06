require 'test_helper'

class CommercegateTest < Test::Unit::TestCase
  def setup
    @gateway = CommercegateGateway.new(
                 :apiUsername => 'usrID',
                 :apiPassword => 'usrPass'
               )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
                :first_name         => 'John',
                :last_name          => 'Doe',
                :number             => '5333339469130529',
                :month              => '01',
                :year               => '2019',
                :verification_value => '123')
                
  end

  ###
  def test_successful_systemtest
    @gateway.expects(:ssl_post).returns(successful_systemtest_response)

    assert response = @gateway.systemtest()
    
    assert response['returnCode'] == '0'
  end
  
  def test_sucessful_auth
    @gateway.expects(:ssl_post).returns(successful_auth_response)

    assert response = @gateway.authorize(@credit_card)
    assert response['action'] == 'AUTH'
    assert response['returnCode'] == '0'
    assert response['token'] == "Hf4lDYcKdJsdX92WJ2CpNlEUdh05utsI"
    assert response['transID'] == "100130291387"
    assert response['amount'] == '10'
    assert response['currencyCode'] == 'EUR'  
    assert response['authCode'] == '726293'
    assert response['cvvCode'] == 'S'
    assert response['avsCode'] == 'U'
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    transID = '100130291387'
    options = {}
    assert response = @gateway.capture(transID, options)
    assert response['action'] == 'CAPTURE'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130291402'
    assert response['amount'] == '10'
    assert response['currencyCode'] == 'EUR'
  end

  def test_successful_sale
    @gateway.expects(:ssl_post).returns(successful_sale_response)
    transID = '100130291387'
    options = {}
    assert response = @gateway.sale(@credit_card, options)
    assert response['action'] == 'SALE'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130291412'
    assert response['token'] == 'rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz'
    assert response['amount'] == '15.00'
    assert response['currencyCode'] == 'EUR'
    assert response['authCode'] == '040404'
  end
  
  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    transID = '100130291387'
    options = {}
    assert response = @gateway.refund(transID, options)
    assert response['action'] == 'REFUND'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130291425'    
    assert response['amount'] == '15.00'
    assert response['currencyCode'] == 'EUR'
    
  end

  def test_successful_rebillauth
    @gateway.expects(:ssl_post).returns(successful_rebillauth_response)
    transID = '100130291387'
    options = {}
    assert response = @gateway.rebill_auth(@credit_card, options)
    assert response['action'] == 'REBILL_AUTH'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130291447'    
    assert response['amount'] == '10.00'
    assert response['currencyCode'] == 'EUR'
    assert response['authCode'] == '533050'
  end

  def test_successful_rebill_sale
    @gateway.expects(:ssl_post).returns(successful_rebillsale_response)
    transID = '100130291470'
    options = {}
    assert response = @gateway.rebill_sale(@credit_card, options)
    assert response['action'] == 'REBILL_SALE'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130291470'    
    assert response['amount'] == '15.00'
    assert response['currencyCode'] == 'EUR'
    assert response['authCode'] == '582165'    
  end
    
  def test_successful_void_auth
    @gateway.expects(:ssl_post).returns(successful_voidauth_response)
    transID = '100130425094'
    options = {}
    assert response = @gateway.void_auth(transID)
    assert response['action'] == 'VOID_AUTH'
    assert response['returnCode'] == '0'
    assert response['transID'] == '100130425094'    
    assert response['amount'] == '10'
    assert response['currencyCode'] == 'EUR'       
  end
  
  # not supported
  # TODO
  def successful_void_capture
    
  end
  
  def successful_void_refund
    
  end
  
  def successful_void_sale
    
  end

  private
  # Place raw successful response from gateway here
  
  def successful_systemtest_response
    return "action=SYSTEM_TEST&returnCode=0&returnText=Success"    
  end
  
  def successful_auth_response
    "action=AUTH&returnCode=0&returnText=Success&authCode=726293&avsCode=U&cvvCode=S&amount=10&currencyCode=EUR&transID=100130291387&token=Hf4lDYcKdJsdX92WJ2CpNlEUdh05utsI"
  end
  
  def successful_capture_response
    "action=CAPTURE&returnCode=0&returnText=Success&amount=10&currencyCode=EUR&transID=100130291402"
  end

  def successful_sale_response
    "action=SALE&returnCode=0&returnText=Success&authCode=040404&avsCode=U&cvvCode=S&amount=15.00&currencyCode=EUR&transID=100130291412&token=rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz"
  end
  
  def successful_refund_response
    "action=REFUND&returnCode=0&returnText=Success&amount=15.00&currencyCode=EUR&transID=100130291425"
  end
  
  def successful_rebillauth_response
    "action=REBILL_AUTH&returnCode=0&returnText=Success&authCode=533050&avsCode=U&cvvCode=S&amount=10.00&currencyCode=EUR&transID=100130291447"
  end
  
  def successful_rebillsale_response
    "action=REBILL_SALE&returnCode=0&returnText=Success&authCode=582165&avsCode=U&cvvCode=S&amount=15.00&currencyCode=EUR&transID=100130291470"
  end
  
  def successful_voidauth_response
    "action=VOID_AUTH&returnCode=0&returnText=Success&amount=10&currencyCode=EUR&transID=100130425094"
  end
  
  # not supported
  # TODO
  def successful_voidcapture_response
    
  end
  
  def successful_voidrefund_response
    
  end

  def successful_voidsale_response
    
  end   

end
