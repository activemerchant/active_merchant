require 'test_helper'

class AuthorizeNetCardPresentTest < Test::Unit::TestCase
  def setup
    @gateway_options = {
      :login => 'X',
      :password => 'Y',
      :device_type => AuthorizeNetCardPresentGateway::DEVICE_TYPES[:unknown],
    }
    @gateway = AuthorizeNetCardPresentGateway.new(@gateway_options)
    @amount = 100
    @credit_card = credit_card
    @subscription_id = '100748'
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization
    assert_equal '000000', response.authorization_code
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '2194822223', response.authorization
    assert_equal 'X931M4', response.authorization_code
  end
  
  def test_parsing_purchase_response_with_card_number_and_type
    res = @gateway.send(:parse, successful_purchase_response)
    assert_equal( 
      res, 
      {
        :response_code=>1,
        :response_reason_code=>"1",
        :response_reason_text=>"This transaction has been approved.",
        :authorization_code=>"X931M4",
        :avs_result_code=>"Y",
        :transaction_id=>"2194822223",
        :card_code=>"",
        :card_number=>"XXXX1111",
        :card_type=>"Visa"
      }
    )
  end


  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '2470195494', response.authorization
    assert_equal '000000', response.authorization_code
  end
  
  def test_add_address_outsite_north_america
    result = {}
    
    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''} )
    
    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'n/a', result[:state]
    assert_equal '164 Waverley Street', result[:address] 
    assert_equal 'DE', result[:country]     
  end
                                                             
  def test_add_address
    result = {}
    
    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    
    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result[:state]
    assert_equal '164 Waverley Street', result[:address]
    assert_equal 'US', result[:country]
    
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, :order_id => '#1001')
    assert_equal '#1001', result[:invoice_num]
  end
  
  def test_add_description
    result = {}
    @gateway.send(:add_invoice, result, :description => 'My Purchase is great')
    assert_equal 'My Purchase is great', result[:description]
  end
  
  def test_add_duplicate_window_without_duplicate_window
    result = {}
    ActiveMerchant::Billing::AuthorizeNetCardPresentGateway.duplicate_window = nil
    @gateway.send(:add_duplicate_window, result)
    assert_nil result[:duplicate_window]
  end
  
  def test_add_duplicate_window_with_duplicate_window
    result = {}
    ActiveMerchant::Billing::AuthorizeNetCardPresentGateway.duplicate_window = 0
    @gateway.send(:add_duplicate_window, result)
    assert_equal 0, result[:duplicate_window]
  end
  
  def test_purchase_meets_minimum_requirements
    params = { :amount => "1.01" }
    @gateway.send(:add_creditcard, params, @credit_card)
    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    minimum_requirements.each do |key|
      assert_match /x_#{key}=/, data
    end
  end
  
  def test_purchase_includes_values_from_gateway_options
    params = { :amount => "1.01" }
    @gateway.send(:add_creditcard, params, @credit_card)
    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    [:login, :password, :device_type].each do |key|
      assert_match /x_[a-z_]+=#{@gateway_options[key]}/, data
    end
  end
  
  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end
  
  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)
    
    assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit', response.message
  end
  
  def test_supported_countries
    assert_equal ['US', 'CA', 'GB'], AuthorizeNetCardPresentGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb], AuthorizeNetCardPresentGateway.supported_cardtypes
  end
  
  def test_failure_without_response_reason_text
    assert_nothing_raised do
      assert_equal '', @gateway.send(:message_from, {})
    end
  end

  private

  def minimum_requirements
    %w(cpversion login tran_key market_type device_type response_format delim_char encap_char amount card_num exp_date type)
  end
  
  def failed_credit_response
    '$3$,$2$,$54$,$The referenced transaction does not meet the criteria for issuing a credit.$,$$,$P$,$0$,$$,$$,$1.00$,$CC$,$credit$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$39265D8BA0CDD4F045B5F4129B2AAA01$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def successful_authorization_response
    '$1.0$,$1$,$1$,$This transaction has been approved.$,$000000$,$P$,$$,$508141794$,$77F2FA67D1A4D2FBAB51F243D90BAB26$,$$'
  end

  def successful_purchase_response
    "$1.0$,$1$,$1$,$This transaction has been approved.$,$X931M4$,$Y$,$$,$2194822223$,$7FE879E74A388D4E4BC056244A434BC7$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$XXXX1111$,$Visa$"
  end
  
  def failed_authorization_response
    '$1.0$,$2$,$2$,$This transaction has been declined.$,$000000$,$P$,$$,$2470195494$,$4DA279AC13040A1CC8B0E5796D3E9D70$,$$'
  end
end
