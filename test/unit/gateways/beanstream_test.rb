require 'test_helper'

class BeanstreamTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = BeanstreamGateway.new(
                 :login => 'merchant id',
                 :user => 'username',
                 :password => 'password'
               )

    @credit_card = credit_card
    
    @check       = check(
                     :institution_number => '001',
                     :transit_number     => '26729'
                   )
    
    @amount = 1000
    
    @options = { 
      :order_id => '1234',
      :billing_address => {
        :name => 'xiaobo zzz',
        :phone => '555-555-5555',
        :address1 => '1234 Levesque St.',
        :address2 => 'Apt B',
        :city => 'Montreal',
        :state => 'QC',
        :country => 'CA',
        :zip => 'H2C1X8'
      },
      :email => 'xiaobozzz@example.com',
      :subtotal => 800,
      :shipping => 100,
      :tax1 => 100,
      :tax2 => 100,
      :custom => 'reference one'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '10000028;15.00;P', response.authorization
  end
  
  def test_successful_test_request_in_production_environment
    Base.mode = :production
    @gateway.expects(:ssl_post).returns(successful_test_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'R', response.avs_result['code']
  end
  
  def test_ccv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
    
  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_check_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '10000072;15.00;D', response.authorization
    assert_equal 'Approved', response.message
  end

  
  # Testing Non-American countries
  
  def test_german_address_sets_state_to_the_required_dummy_value
    @gateway.expects(:commit).with(german_address_params_without_state)
    billing = @options[:billing_address]
    billing[:country]  = 'DE'
    billing[:city]     = 'Berlin'
    billing[:zip]      = '12345'
    billing[:state]    = nil
    @options[:shipping_address] = billing
    
    @gateway.purchase(@amount, @credit_card, @options)
  end
  
  def test_brazilian_address_sets_state_and_zip_to_the_required_dummy_values
    @gateway.expects(:commit).with(brazilian_address_params_without_zip_and_state)
    billing = @options[:billing_address]
    billing[:country]  = 'BR'
    billing[:city]     = 'Rio de Janeiro'
    billing[:zip]      = nil
    billing[:state]    = nil
    @options[:shipping_address] = billing
    
    @gateway.purchase(@amount, @credit_card, @options)
  end
  
  
  private
    
  def successful_purchase_response
    "cvdId=1&trnType=P&trnApproved=1&trnId=10000028&messageId=1&messageText=Approved&trnOrderNumber=df5e88232a61dc1d0058a20d5b5c0e&authCode=TEST&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=6%2F5%2F2008+5%3A26%3A53+AM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+f"
  end
  
  def successful_test_purchase_response
    "merchant_id=100200000&trnId=11011067&authCode=TEST&trnApproved=1&avsId=M&cvdId=1&messageId=1&messageText=Approved&trnOrderNumber=1234"
  end
  
  def unsuccessful_purchase_response
    "merchant_id=100200000&trnId=11011069&authCode=&trnApproved=0&avsId=0&cvdId=6&messageId=16&messageText=Duplicate+transaction&trnOrderNumber=1234"
  end
  
  def successful_check_purchase_response
    "trnApproved=1&trnId=10000072&messageId=1&messageText=Approved&trnOrderNumber=5d9f511363a0f35d37de53b4d74f5b&authCode=&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=6%2F4%2F2008+6%3A33%3A55+PM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+for+this+transaction%2E&trnType=D&paymentMethod=EFT&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end
  
  def brazilian_address_params_without_zip_and_state
    { :shipProvince => '--', :shipPostalCode => '000000', :ordProvince => '--', :ordPostalCode => '000000', :ordCountry => 'BR', :trnCardOwner => 'Longbob Longsen', :shipCity => 'Rio de Janeiro', :ordAddress1 => '1234 Levesque St.', :ordShippingPrice => '1.00', :deliveryEstimate => nil, :shipName => 'xiaobo zzz', :trnCardNumber => '4242424242424242', :trnAmount => '10.00', :trnType => 'P', :ordAddress2 => 'Apt B', :ordTax1Price => '1.00', :shipEmailAddress => 'xiaobozzz@example.com', :trnExpMonth => '09', :ordCity => 'Rio de Janeiro', :shipPhoneNumber => '555-555-5555', :ordName => 'xiaobo zzz', :trnExpYear => next_year, :trnOrderNumber => '1234', :shipCountry => 'BR', :ordTax2Price => '1.00', :shipAddress1 => '1234 Levesque St.', :ordEmailAddress => 'xiaobozzz@example.com', :trnCardCvd => '123', :trnComments => nil, :shippingMethod => nil, :ref1 => 'reference one', :shipAddress2 => 'Apt B', :ordPhoneNumber => '555-555-5555', :ordItemPrice => '8.00' }
  end

  def german_address_params_without_state
    { :shipProvince => '--', :shipPostalCode => '12345', :ordProvince => '--', :ordPostalCode => '12345', :ordCountry => 'DE', :trnCardOwner => 'Longbob Longsen', :shipCity => 'Berlin', :ordAddress1 => '1234 Levesque St.', :ordShippingPrice => '1.00', :deliveryEstimate => nil, :shipName => 'xiaobo zzz', :trnCardNumber => '4242424242424242', :trnAmount => '10.00', :trnType => 'P', :ordAddress2 => 'Apt B', :ordTax1Price => '1.00', :shipEmailAddress => 'xiaobozzz@example.com', :trnExpMonth => '09', :ordCity => 'Berlin', :shipPhoneNumber => '555-555-5555', :ordName => 'xiaobo zzz', :trnExpYear => next_year, :trnOrderNumber => '1234', :shipCountry => 'DE', :ordTax2Price => '1.00', :shipAddress1 => '1234 Levesque St.', :ordEmailAddress => 'xiaobozzz@example.com', :trnCardCvd => '123', :trnComments => nil, :shippingMethod => nil, :ref1 => 'reference one', :shipAddress2 => 'Apt B', :ordPhoneNumber => '555-555-5555', :ordItemPrice => '8.00' }
  end
  
  def next_year
    (Time.now.year + 1).to_s[/\d\d$/]
  end
end
