require 'test_helper'

class CommercegateTest < Test::Unit::TestCase
  def setup
    @gateway = CommercegateGateway.new(
                 :login => 'usrID',
                 :password => 'usrPass'
               )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
                :first_name         => 'John',
                :last_name          => 'Doe',
                :number             => '5333339469130529',
                :month              => '01',
                :year               => '2019',
                :verification_value => '123')
                
    @amount = 1000
    
    @address = {
      :address1 => '', # conditional, required if country is USA or Canada
      :city => '', # conditional, required if country is USA or Canada
      :state => '',# conditional, required if country is USA or Canada      
      :zip => '', # conditional, required if country is USA or Canada
      :country => 'US' # required
    }
    
    @options = {
      :ip => '192.168.7.175', # conditional, required for authorize and purchase
      :email => 'john_doe01@yahoo.com', # required
      :merchant => '', # conditional, required only when you have multiple merchant accounts  
      :currency => 'EUR', # required
      :address => @address,   
      # conditional, required for authorize and purchase
      :site_id => '123', # required
      :offer_id => '321' # required
    }
                
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291387', response.authorization
    assert_equal 'U', response.params['avsCode']
    assert_equal 'S', response.params['cvvCode']
  end

  def test_successful_capture
    trans_id = '100130291387'
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(nil, trans_id, @options)
    assert_instance_of Response, response
    assert_success response    
    assert_equal '100130291402', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100130291412', response.authorization
    assert_equal 'U', response.params['avsCode']
    assert_equal 'S', response.params['cvvCode']
    assert_equal 'rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz', response.params['token']
  end
     
  def test_successful_refund
    trans_id = '100130291387'
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(nil, trans_id, @options)
    assert_instance_of Response, response
    assert_success response    
    assert_equal '100130291425', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']    
  end


  def test_successful_void
    trans_id = '100130291412'
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(trans_id, @options)
    assert_instance_of Response, response
    assert_success response    
    assert_equal '100130425094', response.authorization
    assert_equal '10.00', response.params['amount']
    assert_equal 'EUR', response.params['currencyCode']      
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response_invalid_country)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-103', response.params['returnCode']
  end
  
  def test_unsuccessful_capture_empty_trans_id
    @gateway.expects(:ssl_post).returns(failed_request_response)
    assert response = @gateway.capture(nil, '', @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-125', response.params['returnCode']    
  end

  def test_unsuccessful_capture_trans_id_not_found
    @gateway.expects(:ssl_post).returns(failed_capture_response_invalid_trans_id)
    assert response = @gateway.capture(nil, '', @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '-121', response.params['returnCode']   
  end
  
  private
  
  def failed_request_response
    "returnCode=-125&returnText=Invalid+operation"
  end

  def successful_purchase_response
    "action=SALE&returnCode=0&returnText=Success&authCode=040404&avsCode=U&cvvCode=S&amount=10.00&currencyCode=EUR&transID=100130291412&token=rdkhkRXjPVCXf5jU2Zz5NCcXBihGuaNz"
  end
  
  def successful_authorize_response
    "action=AUTH&returnCode=0&returnText=Success&authCode=726293&avsCode=U&cvvCode=S&amount=10.00&currencyCode=EUR&transID=100130291387&token=Hf4lDYcKdJsdX92WJ2CpNlEUdh05utsI"
  end

  def failed_authorize_response_invalid_country
    "action=AUTH&returnCode=-103&returnText=Invalid+country"
  end

  def successful_capture_response
    "action=CAPTURE&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130291402"
  end
  
  def failed_capture_response_invalid_trans_id
    "action=CAPTURE&returnCode=-121&returnText=Previous+transaction+not+found"
  end

  def successful_refund_response
    "action=REFUND&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130291425"
  end

  def successful_void_response
    "action=VOID_AUTH&returnCode=0&returnText=Success&amount=10.00&currencyCode=EUR&transID=100130425094"
  end

end
