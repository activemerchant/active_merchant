require 'test_helper'

class RemoteCommercegateTest < Test::Unit::TestCase

  # Contact Support at it_support@commercegate.com

  def setup
    @gateway = CommercegateGateway.new(
      :apiUsername => 'XXXXXX',  # Contact support for username / password
      :apiPassword => 'XXXXXX'
    )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :first_name         => 'John', #Any name will work
      :last_name          => 'Doe',
      :number             => 'XXXXXXXXXXXXXXXXX', # Contact support for test card number(s)
      :month              => '01', # Any future date will work
      :year               => '2019',
      :verification_value => '123') # Any 3 digit code will work
                
    @offer_options = {
      :customerIP  => '192.168.7.175', #Any valid IP will work
      :postalCode  => '90230', 
      :countryCode => 'US',
      :siteID      => 'XXXXXXXXXXXX', # Contact support for test site ID
      :offerID     => 'XXXXXXXXXXXX', # Contact support for test OFFER ID
      :email       => 'john_doe01@yahoo.com', # Any valid unique email will work
      :currencyCode=> 'EUR', # Must match the offerID
      :amount      => '10.00' # Must match the offerID
    }
                
  end

  ###
  def test_successful_systemtest
    assert response = @gateway.systemtest()
    assert response['returnCode'] == '0', response_message(response)
  end
  
  def test_sucessful_auth
    assert response = @gateway.authorize(@credit_card, @offer_options)
    assert response['action'] == 'AUTH'
    assert response['returnCode'] == '0', response_message(response)
  end
  
  def test_successful_capture
    assert response = @gateway.authorize(@credit_card, @offer_options)
    assert transID = response['transID']
    options = {}
    assert response = @gateway.capture(transID, options)
    assert response['action'] == 'CAPTURE'
    assert response['returnCode'] == '0', response_message(response)
  end

  def test_successful_sale
    assert response = @gateway.sale(@credit_card, @offer_options)
    assert response['action'] == 'SALE'
    assert response['returnCode'] == '0', response_message(response)
  end
  
  def test_successful_refund
    assert response = @gateway.sale(@credit_card, @offer_options)
    assert transID = response['transID']
    options = {}
    assert response = @gateway.refund(transID, options)
    assert response['action'] == 'REFUND'
    assert response['returnCode'] == '0', response_message(response)
  end

  def test_successful_rebillauth
    assert response = @gateway.authorize(@credit_card, @offer_options)
    assert token = response['token']
    options = {}
    assert response = @gateway.rebill_auth(token, @offer_options)
    assert response['action'] == 'REBILL_AUTH'
    assert response['returnCode'] == '0', response_message(response)
  end

  def test_successful_rebill_sale
    assert response = @gateway.sale(@credit_card, @offer_options)
    assert token = response['token']
    assert response = @gateway.rebill_sale(token, @offer_options)
    assert response['action'] == 'REBILL_SALE'
    assert response['returnCode'] == '0', response_message(response)    
  end
    
  def test_successful_void_auth
    assert response = @gateway.authorize(@credit_card, @offer_options)
    assert transID = response['transID']   
    assert response = @gateway.void_auth(transID)
    assert response['action'] == 'VOID_AUTH'
    assert response['returnCode'] == '0', response_message(response)
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
  
  def response_message(response = {})
    "Return code = " + response['returnCode'] + " " + response['returnText']
  end
end
