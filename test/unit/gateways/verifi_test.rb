require File.dirname(__FILE__) + '/../../test_helper'

class VerifiTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  LOGIN = 'demo'
  PASSWORD = 'password'

  def setup
    @gateway = VerifiGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )
    
    @creditcard = credit_card('4111111111111111')
    
    @options = {
      :order_id => 37,
      :email => "paul@domain.com",   
      :address => { 
         :address1 => '164 Waverley Street', 
         :address2 => 'APT #7', 
         :country => 'US', 
         :city => 'Boulder', 
         :state => 'CO', 
         :zip => 12345 
         }     
    }
  end

  def test_purchase_success    
    @creditcard.number = 1
    
    assert response = @gateway.purchase(100, @creditcard, @options)
    assert response.success?     
  end

  def test_purchase_error
    @creditcard.number = 2
    
    assert response = @gateway.purchase(10, @creditcard, @options)
    assert !response.success?
  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(Money.new(100), @creditcard, { :order_id => 1 } )    
    end  
  end
  
  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, Money.new(1034))
    assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
    assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
    end
  end
                                                 
  def test_add_description
    result = {}
    @gateway.send(:add_invoice_data, result, :description => 'My Purchase is great')
    assert_equal 'My Purchase is great', result[:orderdescription]
    
  end

  def test_purchase_meets_minimum_requirements
    post = VerifiGateway::VerifiPostData.new
    post[:amount] = "1.01"                                          
  
    @gateway.send(:add_creditcard, post, @creditcard)
                                                       
    assert data = @gateway.send(:post_data, :authorization, post)
    
    minimum_requirements.each do |key| 
      assert_not_nil(data =~ /#{key}=/)
    end
    
  end

  private
  
  def minimum_requirements
    %w(type username password ccnumber ccexp amount)
  end
  
  #EXAMPLE RESPONSE: response=3&responsetext=Invalid+Card&authcode=&transactionid=12345&avsresponse=&cvvresponse=

end
